import Foundation
import AppKit
import PDFKit
import UniformTypeIdentifiers

/// A supporting file a founder hands Pickle — a pitch deck, a competitor
/// screenshot, customer-interview notes, a research doc. Text-bearing files
/// (pdf / docs / notes) are flattened to plain text and folded into the prompt;
/// images are downscaled and carried as base64 for the model's vision.
///
/// Stored inline on the `BrainDumpRecord` so materials persist with the session
/// and inform every follow-up. Everything stays local until a reply is sent.
struct Attachment: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case text, pdf, image, document }

    var id: UUID
    var name: String
    var kind: Kind
    var byteSize: Int
    var extractedText: String?   // text / pdf / document → folded into context
    var imageBase64: String?     // image → vision block
    var imageMediaType: String?  // e.g. "image/jpeg"

    init(id: UUID = UUID(), name: String, kind: Kind, byteSize: Int,
         extractedText: String? = nil, imageBase64: String? = nil, imageMediaType: String? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.byteSize = byteSize
        self.extractedText = extractedText
        self.imageBase64 = imageBase64
        self.imageMediaType = imageMediaType
    }

    // MARK: Display

    var iconName: String {
        switch kind {
        case .image:    return "photo"
        case .pdf:      return "doc.richtext"
        case .document: return "doc.text"
        case .text:     return "doc.plaintext"
        }
    }

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file)
    }

    // MARK: Prompt payloads

    /// How this file is folded into Pickle's text context (nil for images).
    var contextBlock: String? {
        guard let t = extractedText, !t.isEmpty else { return nil }
        return "----- Attached file: \(name) -----\n\(t)"
    }

    /// Vision payload for image attachments (nil otherwise).
    var replyImage: ReplyImage? {
        guard kind == .image, let b = imageBase64, let m = imageMediaType else { return nil }
        return ReplyImage(base64: b, mediaType: m, name: name)
    }
}

/// Reads a file off disk into an `Attachment`, extracting text where possible
/// and downscaling images so they stay within model + storage limits.
enum AttachmentLoader {
    static let maxImageDimension: CGFloat = 1568   // matches vision model sweet spot
    static let textCharacterCap = 20_000           // keep prompts bounded

    /// Extensions we'll read as plain text (UTF-8 / Latin-1).
    static let textExtensions: Set<String> =
        ["txt", "text", "md", "markdown", "mdown", "csv", "tsv", "json", "log", "xml", "yaml", "yml"]
    /// Rich documents NSAttributedString can flatten.
    static let docExtensions: Set<String> =
        ["rtf", "rtfd", "doc", "docx", "odt", "html", "htm", "webarchive"]

    enum LoadError: LocalizedError {
        case unsupported(String)
        case unreadable(String)
        var errorDescription: String? {
            switch self {
            case .unsupported(let n): return "Pickle can't read “\(n)”. Try a PDF, image, text, markdown, or doc file."
            case .unreadable(let n):  return "Pickle couldn't open “\(n)”."
            }
        }
    }

    @MainActor
    static func load(url: URL) throws -> Attachment {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        // Images → downscaled JPEG for vision.
        if let type = UTType(filenameExtension: ext), type.conforms(to: .image) {
            guard let image = NSImage(contentsOf: url), let jpeg = downscaledJPEG(image) else {
                throw LoadError.unreadable(name)
            }
            return Attachment(name: name, kind: .image, byteSize: size,
                              imageBase64: jpeg.base64EncodedString(), imageMediaType: "image/jpeg")
        }

        // PDFs → extracted text via PDFKit.
        if ext == "pdf" {
            let text = PDFDocument(url: url)?.string ?? ""
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LoadError.unreadable(name)
            }
            return Attachment(name: name, kind: .pdf, byteSize: size, extractedText: cap(text))
        }

        // Rich documents → NSAttributedString auto-detects the format.
        if docExtensions.contains(ext) {
            if let attr = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                return Attachment(name: name, kind: .document, byteSize: size, extractedText: cap(attr.string))
            }
        }

        // Plain-text family (and a strict-UTF8 fallback for unknown extensions).
        if let data = try? Data(contentsOf: url) {
            if textExtensions.contains(ext) || docExtensions.contains(ext),
               let text = decodeText(data) {
                return Attachment(name: name, kind: .text, byteSize: size, extractedText: cap(text))
            }
            if let text = String(data: data, encoding: .utf8) {   // unknown ext, but it's valid text
                return Attachment(name: name, kind: .text, byteSize: size, extractedText: cap(text))
            }
        }

        throw LoadError.unsupported(name)
    }

    // MARK: Helpers

    private static func cap(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > textCharacterCap else { return t }
        return String(t.prefix(textCharacterCap)) + "\n…[truncated]"
    }

    private static func decodeText(_ data: Data) -> String? {
        String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
    }

    private static func downscaledJPEG(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        let w = CGFloat(rep.pixelsWide), h = CGFloat(rep.pixelsHigh)
        guard w > 0, h > 0 else { return nil }
        let scale = min(1, maxImageDimension / max(w, h))
        let tw = max(1, Int(w * scale)), th = max(1, Int(h * scale))

        guard let target = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: tw, pixelsHigh: th,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        target.size = NSSize(width: tw, height: th)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: target)
        rep.draw(in: NSRect(x: 0, y: 0, width: tw, height: th))
        NSGraphicsContext.restoreGraphicsState()

        return target.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }
}
