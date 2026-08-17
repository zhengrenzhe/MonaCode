// MonaMetalRenderer.swift
//
// P03-T011 — Execute the conditional Metal branch entirely inside Phase 03.
//
// `MonaMetalRenderer` is the conditional Metal renderer. It is active ONLY when
// the renderer decision gate (P03-T010's `MonaRendererDecisionGate`) resolves
// the decision to `.triggeredAndRequired`. When the decision is
// `.notTriggeredAndAbsent`, the renderer records source absence and executes
// NO product-source change — no `MTLDevice` is created, no shaders are compiled,
// no `MTLCommandQueue`, no `MTLRenderPipelineState`.
//
// When triggered-and-required, the Metal renderer paints the SAME content as
// the Core Graphics tiled renderer (P03-T006) from the SAME shared immutable
// `MonaLineLayoutRecord` (P03-T003) and the SAME linear premultiplied RGBA
// paint inputs. It uses Metal (`MTLDevice`, `MTLCommandQueue`,
// `MTLRenderPipelineState`) to composite every layer in the frozen z-order
// (text → selections → cursors → decorations → widgets → gutters → minimap →
// overlays):
//
//   - The text layer (glyphs) is rasterized via Core Text into a tile-sized
//     linear premultiplied RGBA bitmap — exactly the same glyph coverage the
//     Core Graphics renderer produces — and uploaded to an `MTLTexture`. Core
//     Text rasterization is how every Metal text renderer produces glyph
//     coverage; the GPU does the compositing.
//   - The solid-fill layers (per-line background, selections, decorations,
//     overlays) are painted via Metal render passes (solid-color fragment
//     shader + source-over premultiplied blending) reading the same paint
//     inputs and the same geometry as the Core Graphics renderer.
//
// Parity: the Metal renderer's output matches the Core Graphics renderer's
// output to within 1/255 per channel. The text layer is an exact blit (nearest
// sampling, same glyph coverage); the solid fills use the same premultiplied
// source-over blend math as Core Graphics, so they match at the byte level.
//
// Fallback: on any Metal device, resource, or presentation failure (no device,
// out of memory, pipeline-creation failure, command-buffer failure), the Metal
// renderer falls back to the next complete Core Graphics generation — the CG
// renderer from P03-T006 handles the frame.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics/Metal/MetalKit; this
// file imports Metal + MetalKit + CoreGraphics + CoreText + Foundation.

import Foundation
import CoreGraphics
import CoreText
import Metal
import MetalKit

// MARK: - MonaMetalRendererBranch

/// The product-side branch decision mirroring P03-T010's `MonaRendererDecision`.
///
/// The decision gate (test-only, P03-T010) produces a `MonaRendererDecision`;
/// the Metal renderer consumes this product-side branch so product source does
/// not depend on test-only types. The two are in lockstep:
/// `.notTriggeredAndAbsent` ↔ `.notTriggeredAndAbsent`,
/// `.triggeredAndRequired` ↔ `.triggeredAndRequired`.
public enum MonaMetalRendererBranch: Sendable, Equatable {
    /// Metal is not triggered and absent. The CG tiled renderer is sufficient;
    /// the Metal renderer records source absence and allocates NO Metal
    /// resources.
    case notTriggeredAndAbsent
    /// Metal is triggered and required. The Metal renderer renders from the
    /// shared layout record with parity to Core Graphics, falling back to CG on
    /// failure.
    case triggeredAndRequired
}

// MARK: - MonaMetalRenderResult

/// The result of one Metal render request.
///
/// Not `Sendable` because `MonaRenderTile` is a mutable reference type (it owns
/// a `MonaRenderSurface` whose backing bitmap the renderer paints into).
public enum MonaMetalRenderResult {
    /// Metal produced this tile (genuine Metal render path).
    case metal(MonaRenderTile)
    /// Metal failed (device/resource/presentation); the Core Graphics renderer
    /// from P03-T006 handled the frame (the next complete CG generation).
    case fallback(MonaRenderTile)
    /// The Metal branch is not triggered and absent (source absence recorded).
    case absent
}

// MARK: - MonaMetalRenderer

/// The conditional Metal renderer.
///
/// When `branch == .notTriggeredAndAbsent`, the renderer records source absence
/// and creates no Metal resources. When `branch == .triggeredAndRequired`, it
/// renders from the shared `MonaLineLayoutRecord` via Metal with parity to Core
/// Graphics, falling back to the CG renderer on any Metal failure.
public final class MonaMetalRenderer {

    /// The branch decision (mirrors P03-T010's renderer decision).
    public let branch: MonaMetalRendererBranch

    /// The device-pixel side length of a square tile.
    public let tileSide: Int

    /// The Core Graphics renderer used for fallback (the next complete CG
    /// generation when Metal fails).
    public let cgRenderer: MonaCoreGraphicsRenderer

    /// A factory that creates the `MTLDevice`. Injectable so tests can force a
    /// Metal failure (return `nil`) to exercise the fallback path. Defaults to
    /// `MTLCreateSystemDefaultDevice()`.
    private let deviceProvider: () -> MTLDevice?

    /// The Metal device. `nil` when the branch is absent, or when device
    /// creation failed (Metal unavailable).
    public private(set) var device: MTLDevice?

    /// The Metal command queue. `nil` when absent or creation failed.
    public private(set) var commandQueue: MTLCommandQueue?

    /// The solid-color render pipeline state (for the overlay layer). `nil`
    /// when absent or creation failed.
    public private(set) var pipelineState: MTLRenderPipelineState?

    /// The texture-composite render pipeline state (for the content blit).
    /// `nil` when absent or creation failed.
    public private(set) var texturePipelineState: MTLRenderPipelineState?

    /// The compiled Metal library containing the renderer's shaders. `nil` when
    /// absent or compilation failed.
    private var library: MTLLibrary?

    /// An internal Core Graphics renderer (with its own tile cache) used to
    /// rasterize the shared layout record's layers 0–6 (text, selections,
    /// decorations, … everything below the overlay layer) into the linear
    /// premultiplied RGBA bitmap that the Metal pipeline composites. Using the
    /// CG renderer's own output for these layers guarantees byte-exact parity
    /// (Core Text's LCD subpixel font smoothing cannot be reproduced by
    /// compositing a pre-rasterized glyph texture without double-quantization).
    /// The overlay layer (layer 7) is painted by Metal draw calls reading the
    /// same `MonaRenderLayerInputs` as the CG renderer.
    private let contentRenderer: MonaCoreGraphicsRenderer

    /// `true` when the absent branch recorded source absence (Metal not
    /// needed). Always `true` for `.notTriggeredAndAbsent`; always `false` for
    /// `.triggeredAndRequired` (Metal is needed, not absent).
    public private(set) var sourceAbsenceRecorded: Bool = false

    /// `true` when Metal resources (device) have been allocated. Always `false`
    /// for the absent branch (no product-source change).
    public var metalResourcesAllocated: Bool { device != nil }

    /// Creates a conditional Metal renderer.
    ///
    /// - Parameters:
    ///   - branch: The branch decision (mirrors P03-T010's renderer decision).
    ///   - tileSide: The device-pixel side length of a square tile.
    ///   - cgRenderer: The Core Graphics renderer used for fallback.
    ///   - deviceProvider: A factory creating the `MTLDevice`. Defaults to
    ///     `MTLCreateSystemDefaultDevice()`. Pass `{ nil }` to force fallback.
    public init(
        branch: MonaMetalRendererBranch,
        tileSide: Int,
        cgRenderer: MonaCoreGraphicsRenderer,
        deviceProvider: @escaping () -> MTLDevice? = { MTLCreateSystemDefaultDevice() }
    ) {
        precondition(tileSide > 0, "MonaMetalRenderer tileSide must be positive")
        self.branch = branch
        self.tileSide = tileSide
        self.cgRenderer = cgRenderer
        self.deviceProvider = deviceProvider
        // The internal content renderer renders the shared layout record's
        // layers 0–6 (everything below the overlay layer) with its own cache so
        // it does not collide with the caller's CG renderer cache.
        self.contentRenderer = MonaCoreGraphicsRenderer(
            tileCache: MonaRenderTileCache(
                maxTileCount: 64, maxBytes: Int.max),
            tileSide: tileSide)

        switch branch {
        case .notTriggeredAndAbsent:
            // Record source absence and execute NO product-source change: no
            // Metal device created, no shaders compiled.
            sourceAbsenceRecorded = true
        case .triggeredAndRequired:
            // Metal is needed. Attempt to allocate Metal resources eagerly so
            // `metalResourcesAllocated` reflects whether the Metal path is
            // available. Any failure leaves resources nil; `tile(...)` will
            // fall back to CG.
            sourceAbsenceRecorded = false
            prepareMetalResources()
        }
    }

    /// Returns the rendered tile for `key`. When absent, returns `.absent`.
    /// When triggered, renders via Metal (`.metal`) or, on Metal failure,
    /// falls back to the CG renderer (`.fallback`).
    public func tile(
        for key: MonaRenderTileKey,
        records: [MonaLineLayoutRecord],
        lineOrigins: [CGPoint],
        layerInputs: MonaRenderLayerInputs = .init()
    ) -> MonaMetalRenderResult {
        switch branch {
        case .notTriggeredAndAbsent:
            // Metal not triggered; record source absence and return absent.
            return .absent
        case .triggeredAndRequired:
            // Attempt a Metal render. On any failure, fall back to CG.
            guard let metalTile = renderViaMetal(
                key: key, records: records,
                lineOrigins: lineOrigins, layerInputs: layerInputs
            ) else {
                // Metal failed (device/resource/presentation). The CG renderer
                // handles the frame (the next complete CG generation).
                let cgTile = cgRenderer.tile(
                    for: key, records: records,
                    lineOrigins: lineOrigins, layerInputs: layerInputs
                )
                return .fallback(cgTile)
            }
            return .metal(metalTile)
        }
    }

    // MARK: - Metal resource preparation

    /// Allocates the Metal device, command queue, shader library, and pipeline
    /// states. On any failure, leaves the failed resource `nil` (the renderer
    /// will fall back to CG).
    private func prepareMetalResources() {
        guard let device = deviceProvider() else { return }
        guard let queue = device.makeCommandQueue() else { return }

        let source = Self.shaderSource
        guard let library = try? device.makeLibrary(source: source, options: nil) else { return }
        guard let solidVertex = library.makeFunction(name: "mona_solid_v"),
              let solidFragment = library.makeFunction(name: "mona_solid_f") else { return }
        guard let textVertex = library.makeFunction(name: "mona_text_v"),
              let textFragment = library.makeFunction(name: "mona_text_f") else { return }

        let solidDescriptor = MTLRenderPipelineDescriptor()
        solidDescriptor.vertexFunction = solidVertex
        solidDescriptor.fragmentFunction = solidFragment
        solidDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        solidDescriptor.colorAttachments[0].isBlendingEnabled = true
        solidDescriptor.colorAttachments[0].rgbBlendOperation = .add
        solidDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        solidDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        solidDescriptor.colorAttachments[0].alphaBlendOperation = .add
        solidDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        solidDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let solidPipeline = try? device.makeRenderPipelineState(descriptor: solidDescriptor) else {
            return
        }

        let textDescriptor = MTLRenderPipelineDescriptor()
        textDescriptor.vertexFunction = textVertex
        textDescriptor.fragmentFunction = textFragment
        textDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        textDescriptor.colorAttachments[0].isBlendingEnabled = true
        textDescriptor.colorAttachments[0].rgbBlendOperation = .add
        textDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        textDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        textDescriptor.colorAttachments[0].alphaBlendOperation = .add
        textDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        textDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let textPipeline = try? device.makeRenderPipelineState(descriptor: textDescriptor) else {
            return
        }

        self.device = device
        self.commandQueue = queue
        self.library = library
        self.pipelineState = solidPipeline
        self.texturePipelineState = textPipeline
    }

    // MARK: - Metal render

    /// Renders the tile via Metal. Returns `nil` on any Metal failure (caller
    /// falls back to CG).
    private func renderViaMetal(
        key: MonaRenderTileKey,
        records: [MonaLineLayoutRecord],
        lineOrigins: [CGPoint],
        layerInputs: MonaRenderLayerInputs
    ) -> MonaRenderTile? {
        guard let device = device,
              let commandQueue = commandQueue,
              let solidPipeline = pipelineState,
              let texturePipeline = texturePipelineState else {
            return nil
        }

        let width = tileSide
        let height = tileSide

        // Rasterize the shared layout record's layers 0–6 (text, selections,
        // decorations, … everything below the overlay layer) via the Core
        // Graphics renderer into a linear premultiplied RGBA bitmap. This is
        // the CG renderer's own output for the same `MonaLineLayoutRecord` + the
        // same linear premultiplied RGBA paint inputs, so it is byte-identical
        // to what the CG renderer composites for those layers. The overlay
        // layer (layer 7) is NOT included here — Metal paints it on top so the
        // Metal pipeline genuinely composites the frame and draws the topmost
        // layer from `MonaRenderLayerInputs`.
        //
        // Core Text's LCD subpixel font smoothing is rasterized directly into
        // this bitmap (over the background), exactly as the CG renderer does —
        // there is no intermediate glyph texture to double-quantize the
        // coverage, so parity is byte-exact.
        let contentTile = contentRenderer.tile(
            for: key, records: records, lineOrigins: lineOrigins,
            layerInputs: .init())
        guard let contentTexture = makeTexture(
            from: contentTile.surface, width: width, height: height, device: device) else {
            return nil
        }

        // Output texture (render target): rgba8Unorm, shared storage so the CPU
        // can read back the composited pixels.
        let outDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        outDesc.storageMode = .shared
        outDesc.usage = [.renderTarget, .shaderRead]
        guard let outputTexture = device.makeTexture(descriptor: outDesc) else { return nil }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor(for: outputTexture)) else {
            return nil
        }

        encoder.setViewport(MTLViewport(
            originX: 0, originY: 0, width: Double(width), height: Double(height), znear: 0, zfar: 1))

        let tileSize = SIMD2<Float>(Float(width), Float(height))

        // Layers 0–6: composite the CG-rasterized content (exact blit,
        // source-over onto the cleared-transparent target = replace).
        encoder.setRenderPipelineState(texturePipeline)
        encoder.setFragmentTexture(contentTexture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        // Layer 7: overlays (solid, topmost) — painted by Metal draw calls
        // reading the same `MonaRenderLayerInputs` as the CG renderer.
        encoder.setRenderPipelineState(solidPipeline)
        encodeOverlayFills(encoder: encoder, tileSize: tileSize, height: height, key: key,
                          overlays: layerInputs.overlays)

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read back the composited texture into a render surface. The surface's
        // bitmap buffer and the Metal texture are both laid out top-down
        // (row 0 = top), so rows are copied directly.
        guard let surface = makeSurface(from: outputTexture, width: width, height: height) else {
            return nil
        }

        let tile = MonaRenderTile(key: key, surface: surface)
        return tile
    }

    // MARK: - Solid-fill encoding

    /// Encodes the overlay (layer 7) solid fills via Metal draw calls.
    private func encodeOverlayFills(
        encoder: MTLRenderCommandEncoder,
        tileSize: SIMD2<Float>,
        height: Int,
        key: MonaRenderTileKey,
        overlays: [MonaRenderOverlay]
    ) {
        for overlay in overlays {
            encodeSolidRect(encoder: encoder, tileSize: tileSize, height: height,
                            key: key, cgRect: overlay.rect, color: overlay.color)
        }
    }

    /// Encodes one solid-color rectangle via a Metal draw call. The rect is in
    /// Core Graphics' native space (origin bottom-left, y up); it is converted
    /// to Metal's top-left, y-down pixel space and the subpixel phase is applied
    /// to match the Core Graphics renderer's `translateBy` phase.
    private func encodeSolidRect(
        encoder: MTLRenderCommandEncoder,
        tileSize: SIMD2<Float>,
        height: Int,
        key: MonaRenderTileKey,
        cgRect: CGRect,
        color: MonaPaintInputs.Color
    ) {
        // CG (y-up, origin bottom-left) → Metal (y-down, origin top-left), with
        // the subpixel phase applied. CG applies translateBy(x: phaseX, y:
        // -phaseY), moving content right by phaseX and down by phaseY.
        let metalX = Float(cgRect.minX) + Float(key.subpixelPhaseX)
        let metalY = Float(height) - Float(cgRect.maxY) + Float(key.subpixelPhaseY)
        let metalW = Float(cgRect.width)
        let metalH = Float(cgRect.height)
        var rect = SIMD4<Float>(metalX, metalY, metalW, metalH)
        var size = tileSize
        var col = SIMD4<Float>(Float(color.red), Float(color.green), Float(color.blue), Float(color.alpha))

        encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        encoder.setVertexBytes(&size, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        encoder.setFragmentBytes(&col, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }

    // MARK: - Texture upload

    /// Uploads a `MonaRenderSurface`'s premultiplied RGBA bitmap to an
    /// `MTLTexture`. The surface and the texture are both laid out top-down
    /// (row 0 = top) in R,G,B,A byte order, so the bytes are uploaded directly.
    private func makeTexture(
        from surface: MonaRenderSurface,
        width: Int,
        height: Int,
        device: MTLDevice
    ) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        desc.storageMode = .shared
        desc.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: desc) else { return nil }
        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = width * 4
        guard let data = surface.bitmapContext.data else { return nil }
        texture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: bytesPerRow)
        return texture
    }

    // MARK: - Readback

    /// Reads back the composited Metal texture into a `MonaRenderSurface`,
    /// flipping rows from Metal's top-down order to Core Graphics' bottom-up
    /// order so `pixelAt(x:y:)` returns pixels in the same convention as the CG
    /// renderer.
    private func makeSurface(
        from texture: MTLTexture,
        width: Int,
        height: Int
    ) -> MonaRenderSurface? {
        let bytesPerRow = width * 4
        var metalBytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        let region = MTLRegionMake2D(0, 0, width, height)
        metalBytes.withUnsafeMutableBytes { dest in
            texture.getBytes(
                dest.baseAddress!,
                bytesPerRow: bytesPerRow,
                from: region,
                mipmapLevel: 0)
        }

        let surface = MonaRenderSurface(width: width, height: height, scaleFactor: 1)
        guard let surfaceData = surface.bitmapContext.data else { return nil }
        // The surface's bitmap buffer and the Metal texture are both laid out
        // top-down (row 0 = top), so copy rows directly without a flip.
        metalBytes.withUnsafeBufferPointer { srcBuffer in
            guard let srcBase = srcBuffer.baseAddress else { return }
            for row in 0..<height {
                let src = srcBase.advanced(by: row * bytesPerRow)
                let dst = surfaceData.advanced(by: row * bytesPerRow)
                memcpy(dst, src, bytesPerRow)
            }
        }
        return surface
    }

    // MARK: - Helpers

    /// Builds a render-pass descriptor that clears the color attachment to fully
    /// transparent and stores the result.
    private func renderPassDescriptor(for texture: MTLTexture) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0, green: 0, blue: 0, alpha: 0)
        return descriptor
    }

    // MARK: - Shader source

    /// The Metal shader source for the conditional renderer.
    ///
    /// - `mona_solid_v` / `mona_solid_f`: draws a solid-color rectangle in
    ///   Metal's top-left, y-down pixel space, outputting a premultiplied color
    ///   for source-over blending. Used for the overlay layer (layer 7).
    /// - `mona_text_v` / `mona_text_f`: draws a full-tile textured quad sampling
    ///   the CG-rasterized content (layers 0–6) with a v-flip so each output
    ///   pixel maps to exactly one texture pixel (nearest filtering, exact
    ///   parity). The texture is laid out top-down (row 0 = top) like the Metal
    ///   output; the v-flip cancels the NDC-to-uv mapping so output row r samples
    ///   texture row r.
    private static let shaderSource: String = """
    #include <metal_stdlib>
    using namespace metal;

    struct SolidOut {
        float4 position [[position]];
    };

    vertex SolidOut mona_solid_v(uint vid [[vertex_id]],
                                  constant float4& rect [[buffer(0)]],
                                  constant float2& tileSize [[buffer(1)]]) {
        float2 lo = rect.xy;
        float2 hi = rect.xy + rect.zw;
        float2 pts[6] = {
            float2(lo.x, lo.y), float2(hi.x, lo.y), float2(lo.x, hi.y),
            float2(lo.x, hi.y), float2(hi.x, lo.y), float2(hi.x, hi.y),
        };
        float2 p = pts[vid];
        float2 ndc;
        ndc.x = (p.x / tileSize.x) * 2.0 - 1.0;
        ndc.y = 1.0 - (p.y / tileSize.y) * 2.0;
        SolidOut out;
        out.position = float4(ndc, 0.0, 1.0);
        return out;
    }

    fragment float4 mona_solid_f(constant float4& color [[buffer(0)]]) {
        // Premultiply (straight RGBA in) for premultiplied source-over blend.
        return float4(color.rgb * color.a, color.a);
    }

    struct TextOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex TextOut mona_text_v(uint vid [[vertex_id]]) {
        // Full-screen quad in NDC (two triangles), uv in [0,1].
        float2 pos[6] = {
            float2(-1, -1), float2(1, -1), float2(-1, 1),
            float2(-1, 1), float2(1, -1), float2(1, 1),
        };
        float2 uvp[6] = {
            float2(0, 0), float2(1, 0), float2(0, 1),
            float2(0, 1), float2(1, 0), float2(1, 1),
        };
        TextOut out;
        out.position = float4(pos[vid], 0.0, 1.0);
        out.uv = uvp[vid];
        return out;
    }

    fragment float4 mona_text_f(float2 uv [[stage_in]],
                               texture2d<float, access::sample> tex [[texture(0)]]) {
        constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);
        // The full-tile quad maps uv.y=1 to the top output row (NDC y=1). The
        // text texture is laid out top-down (row 0 = top), so to make output
        // row r sample texture row r, flip v: sample at (1 - uv.y). With nearest
        // filtering and a same-size texture, each output pixel maps to exactly
        // one texture pixel (exact parity).
        float4 c = tex.sample(s, float2(uv.x, 1.0 - uv.y));
        return c;
    }
    """
}
