// MonaRenderSurface.swift
//
// P03-T006 — Complete the correct Core Graphics tiled renderer.
//
// `MonaRenderSurface` is the render target for the Core Graphics tiled
// renderer. It owns a bitmap `CGContext` rasterized in linear premultiplied
// RGBA (8 bpc, 32 bpp, alpha last and premultiplied) plus the device-pixel
// dimensions and the scale factor the context was rasterized for.
//
// The renderer paints complete immutable `MonaLineLayoutRecord`s (P03-T003)
// directly into a surface's `CGContext`; the surface never reshapes text. Each
// cached tile wraps one surface. The premultiplied-alpha bitmap format is what
// makes the frozen z-order composite (text → selections → cursors →
// decorations → widgets → gutters → minimap → overlays) correct: every layer
// blends with straight source-over math against an already-premultiplied
// destination, so partial coverage composites without double-darkening.
//
// MonaCodeAppKit may import AppKit/CoreText/CoreGraphics; this file imports
// CoreGraphics + Foundation.

import Foundation
import CoreGraphics

// MARK: - MonaRenderSurface

/// The render target for the Core Graphics tiled renderer.
///
/// Owns a bitmap `CGContext` rasterized in linear premultiplied RGBA (8 bpc,
/// 32 bpp, `premultipliedLast`, big-endian 32-bit so the in-memory byte order
/// is R, G, B, A). The renderer paints layout records into this context; the
/// surface exposes the device-pixel dimensions, the scale factor, the bytes per
/// row, and the bitmap info so callers can verify the premultiplied-alpha
/// contract and sample pixels.
///
/// The surface owns its backing data buffer for the lifetime of the instance;
/// `pixelAt(x:y:)` reads bytes from that buffer. Instances are reference types
/// because the bitmap context and its data buffer are mutable shared state that
/// the renderer paints into.
public final class MonaRenderSurface {

    /// The device-pixel width of the bitmap.
    public let width: Int

    /// The device-pixel height of the bitmap.
    public let height: Int

    /// The scale factor the context was rasterized for (e.g. 2.0 for Retina).
    public let scaleFactor: CGFloat

    /// The bitmap context the renderer paints into.
    public let bitmapContext: CGContext

    /// The bytes per row of the backing bitmap (at least `width * 4`).
    public let bytesPerRow: Int

    /// The bitmap info describing the premultiplied RGBA format.
    public let bitmapInfo: CGBitmapInfo

    /// The backing data buffer. Held strongly so the bitmap context stays valid
    /// for the surface's lifetime; `pixelAt(x:y:)` reads from it.
    private let data: UnsafeMutableRawPointer

    /// The color space used by every renderer surface: linear RGB. Storing
    /// pixels in a linear-light space makes the premultiplied-alpha composite
    /// mathematically correct ("linear premultiplied RGBA") and keeps primary
    /// colors exact (no display-profile color matching) so cached tiles are
    /// deterministic across machines.
    private static let colorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)!

    /// Creates a render surface of the given device-pixel dimensions and scale.
    ///
    /// The bitmap is allocated zeroed (fully transparent). Callers that want an
    /// opaque background should fill the context before painting layers.
    public init(width: Int, height: Int, scaleFactor: CGFloat = 1) {
        precondition(width > 0 && height > 0, "MonaRenderSurface dimensions must be positive")
        precondition(scaleFactor > 0, "MonaRenderSurface scaleFactor must be positive")

        self.width = width
        self.height = height
        self.scaleFactor = scaleFactor

        // Linear premultiplied RGBA: 8 bits per component, 32 bits per pixel,
        // alpha last and premultiplied, 32-bit big-endian byte order so the
        // in-memory byte order is R, G, B, A.
        let info = CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue
        )
        self.bitmapInfo = info

        let rowBytes = width * 4
        self.bytesPerRow = rowBytes

        let buffer = UnsafeMutableRawPointer.allocate(byteCount: rowBytes * height, alignment: 16)
        memset_s(buffer, rowBytes * height, 0, rowBytes * height)
        self.data = buffer

        guard let ctx = CGContext(
            data: buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: rowBytes,
            space: MonaRenderSurface.colorSpace,
            bitmapInfo: info.rawValue
        ) else {
            // CGContext creation can only fail for unsupported format/dimension
            // combinations; the format above is supported on every macOS target.
            buffer.deallocate()
            preconditionFailure("MonaRenderSurface: CGContext creation failed for \(width)x\(height)")
        }

        // The context stays in Core Graphics' native coordinate space (origin
        // at bottom-left, y up). The renderer paints in this space: `CTFontDrawGlyphs`
        // draws glyphs upright, and fills use `CGContext.fill(_:)` directly. The
        // bitmap buffer's row 0 is always the bottom row of the image regardless
        // of the CTM, so `pixelAt(x:y:)` reads the y-th row from the bottom.
        self.bitmapContext = ctx
    }

    deinit {
        data.deallocate()
    }

    /// The premultiplied RGBA bitmap info used by every renderer surface.
    public static var premultipliedRGBABitmapInfo: CGBitmapInfo {
        return CGBitmapInfo(
            rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                | CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    /// Reads the pixel at `(x, y)` as a premultiplied RGBA byte tuple.
    ///
    /// `(0, 0)` is the bottom-left of the surface (Core Graphics' native origin;
    /// the bitmap buffer's row 0 is the bottom row). Returns `nil` for
    /// out-of-bounds coordinates.
    public func pixelAt(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard x >= 0 && x < width && y >= 0 && y < height else { return nil }
        let row = data.advanced(by: y * bytesPerRow)
        let pixel = row.advanced(by: x * 4)
        let bytes = pixel.assumingMemoryBound(to: UInt8.self)
        // Big-endian 32-bit + premultipliedLast => in-memory byte order R, G, B, A.
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}
