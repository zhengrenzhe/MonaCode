// MonaPasteboardGateway.swift
//
// P04-T008 — Implement copy, cut, paste, and paste-edit pipelines.
//
// `MonaPasteboardGateway` is the SINGLE native gateway that reads and writes the
// macOS pasteboard (`NSPasteboard`) — the Swift counterpart of the clipboard
// boundary Monaco routes through its `clipboard` service before pushing text
// into or pulling text out of the editor (monaco-editor 0.56.0). This is the
// one place where AppKit pasteboard representations become Core values.
//
// Responsibilities:
//
//   1. Read and write the EXACT retained plain-text representation (NSString on
//      the pasteboard, surfaced as `String`).
//   2. Read and write the EXACT retained rich-text representation
//      (`NSAttributedString`, round-tripped through RTF on the pasteboard so
//      attributes survive).
//   3. Read and write editor metadata — a custom MonaCode clipboard format
//      (`com.monacode.editor-metadata`) that carries selection / range info so
//      a paste into the same editor can restore the originating selection.
//
// The gateway is stateless beyond the pasteboard reference: two reads with
// equal pasteboard state produce equal results. Construct one per editor host
// with the default `.general` pasteboard, or inject a named pasteboard for
// testing.
//
// `MonaCodeAppKit` may `import AppKit`, `import Foundation`, and `import MonaCode`.

import AppKit
import Foundation
import MonaCode

/// Editor metadata for the custom MonaCode clipboard format — selection / range
/// info carried alongside the plain-text and rich-text representations so a
/// paste into the originating editor can restore the source selection.
///
/// Serialized to JSON on the pasteboard under `MonaPasteboardGateway.monacodeMetadataType`.
/// `Codable` so the gateway can round-trip it through `JSONEncoder` / `JSONDecoder`.
public struct MonaClipboardEditorMetadata: Equatable, Codable {

    /// The source model's URI-derived id at copy time.
    public let sourceModelId: String

    /// The source model's version id at copy time.
    public let sourceVersionId: Int

    /// The selection anchor line (1-based) at copy time.
    public let selectionAnchorLine: Int

    /// The selection anchor column (1-based, raw UTF-16) at copy time.
    public let selectionAnchorColumn: Int

    /// The selection active position line (1-based) at copy time.
    public let selectionActiveLine: Int

    /// The selection active position column (1-based, raw UTF-16) at copy time.
    public let selectionActiveColumn: Int

    /// Creates editor metadata snapshot.
    public init(
        sourceModelId: String,
        sourceVersionId: Int,
        selectionAnchorLine: Int,
        selectionAnchorColumn: Int,
        selectionActiveLine: Int,
        selectionActiveColumn: Int
    ) {
        self.sourceModelId = sourceModelId
        self.sourceVersionId = sourceVersionId
        self.selectionAnchorLine = selectionAnchorLine
        self.selectionAnchorColumn = selectionAnchorColumn
        self.selectionActiveLine = selectionActiveLine
        self.selectionActiveColumn = selectionActiveColumn
    }

    /// Convenience: builds metadata from a model and a selection.
    public init(model: MonaCodeModel, selection: MonaSelection) {
        self.sourceModelId = model.id
        self.sourceVersionId = model.getVersionId()
        self.selectionAnchorLine = selection.anchor.line
        self.selectionAnchorColumn = selection.anchor.column
        self.selectionActiveLine = selection.activePosition.line
        self.selectionActiveColumn = selection.activePosition.column
    }
}

/// The clipboard content read and written by `MonaPasteboardGateway`: the
/// plain-text, rich-text, and editor metadata representations, any of which may
/// be nil when the pasteboard does not carry that flavor.
///
/// Not `Equatable`: `NSAttributedString` has no value equality. Compare the
/// fields individually (e.g. `plainText`, `richTextString`, `metadata`).
public struct MonaClipboardContent {

    /// The plain-text representation (NSString on the pasteboard).
    public let plainText: String?

    /// The rich-text representation (round-tripped through RTF).
    public let richText: NSAttributedString?

    /// The editor metadata (custom MonaCode clipboard format).
    public let metadata: MonaClipboardEditorMetadata?

    /// Creates a clipboard content value.
    public init(
        plainText: String?,
        richText: NSAttributedString?,
        metadata: MonaClipboardEditorMetadata?
    ) {
        self.plainText = plainText
        self.richText = richText
        self.metadata = metadata
    }

    /// Convenience: the rich-text's plain string, or nil if no rich-text.
    public var richTextString: String? {
        return richText?.string
    }
}

/// The single native gateway that reads and writes the macOS pasteboard.
///
/// Construct with `init(pasteboard:)` (defaults to `.general`). Read with
/// `read() -> MonaClipboardContent?` (nil when the pasteboard is empty of all
/// three flavors). Write with `write(_:)` — clears the pasteboard first and
/// publishes whichever of plain-text / rich-text / metadata are non-nil.
public final class MonaPasteboardGateway {

    /// The custom MonaCode pasteboard type carrying editor metadata as JSON.
    public static let monacodeMetadataType = NSPasteboard.PasteboardType("com.monacode.editor-metadata")

    /// The pasteboard this gateway reads and writes.
    public let pasteboard: NSPasteboard

    /// Creates a gateway over `pasteboard` (defaults to the system general
    /// pasteboard).
    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    // MARK: - Read

    /// Reads the pasteboard and returns the clipboard content, or nil when the
    /// pasteboard carries none of the plain-text / rich-text / metadata flavors.
    ///
    /// Reads plain-text via `string(forType:)`, rich-text via `readObjects`,
    /// and metadata via the custom MonaCode type decoded from JSON.
    public func read() -> MonaClipboardContent? {
        let plain = pasteboard.string(forType: .string)
        let rich = readRichText()
        let metadata = readMetadata()

        if plain == nil && rich == nil && metadata == nil {
            return nil
        }
        return MonaClipboardContent(plainText: plain, richText: rich, metadata: metadata)
    }

    // MARK: - Write

    /// Writes `content` to the pasteboard, clearing it first. Publishes
    /// whichever of plain-text / rich-text / metadata are non-nil.
    public func write(_ content: MonaClipboardContent) {
        var types: [NSPasteboard.PasteboardType] = []
        if content.plainText != nil {
            types.append(.string)
        }
        if content.richText != nil {
            types.append(.rtf)
        }
        if content.metadata != nil {
            types.append(MonaPasteboardGateway.monacodeMetadataType)
        }
        guard !types.isEmpty else {
            pasteboard.clearContents()
            return
        }
        pasteboard.clearContents()

        if let plain = content.plainText {
            pasteboard.setString(plain, forType: .string)
        }
        if let rich = content.richText {
            writeRichText(rich)
        }
        if let metadata = content.metadata {
            writeMetadata(metadata)
        }
    }

    // MARK: - Rich-text read / write

    private func readRichText() -> NSAttributedString? {
        guard pasteboard.types?.contains(.rtf) == true else {
            return nil
        }
        if let objects = pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil),
           let attributed = objects.first as? NSAttributedString {
            return attributed
        }
        return nil
    }

    private func writeRichText(_ richText: NSAttributedString) {
        // Round-trip through RTF so attributes survive on the pasteboard.
        do {
            let rtfData = try rtfData(from: richText)
            pasteboard.setData(rtfData, forType: .rtf)
        } catch {
            // RTF encoding failure: fall back to the plain string so the
            // pasteboard is not left with a stale flavor.
            if !richText.string.isEmpty {
                pasteboard.setString(richText.string, forType: .string)
            }
        }
    }

    private func rtfData(from attributedString: NSAttributedString) throws -> Data {
        let range = NSRange(location: 0, length: attributedString.length)
        guard let data = attributedString.rtf(from: range, documentAttributes: [
            .documentType: NSAttributedString.DocumentType.rtf
        ]) else {
            throw NSError(
                domain: "MonaPasteboardGateway",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "RTF encoding returned nil"]
            )
        }
        return data
    }

    // MARK: - Metadata read / write

    private func readMetadata() -> MonaClipboardEditorMetadata? {
        guard let data = pasteboard.data(forType: MonaPasteboardGateway.monacodeMetadataType) else {
            return nil
        }
        return try? JSONDecoder().decode(MonaClipboardEditorMetadata.self, from: data)
    }

    private func writeMetadata(_ metadata: MonaClipboardEditorMetadata) {
        guard let data = try? JSONEncoder().encode(metadata) else {
            return
        }
        pasteboard.setData(data, forType: MonaPasteboardGateway.monacodeMetadataType)
    }
}
