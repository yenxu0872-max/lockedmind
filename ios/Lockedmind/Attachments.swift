// Photos, scanned documents and files: read on the iPhone (Vision finds the
// words in pictures, PDFKit reads PDFs) and handed to the model as text.
// On iOS 27 the model can also look at a photo itself. Nothing is uploaded.

import SwiftUI
import UIKit
import PDFKit
import Vision
import VisionKit
import PhotosUI
import UniformTypeIdentifiers

enum Reader {
    enum Failure: LocalizedError {
        case unreadable(String)
        var errorDescription: String? {
            switch self { case .unreadable(let name): "Lockedmind couldn't open \(name)." }
        }
    }

    /// The file types the file picker offers.
    static let fileTypes: [UTType] = [.pdf, .plainText, .utf8PlainText, .rtf, .commaSeparatedText, .json,
                                       UTType(filenameExtension: "md") ?? .plainText, .sourceCode, .html]

    static func photo(_ data: Data, name: String, into folder: URL) async throws -> Attachment {
        guard let image = UIImage(data: data) else { throw Failure.unreadable(name) }
        let small = downscale(image, to: 1600)
        let file = try save(small, into: folder)
        let text = await recognize(small)
        let (cut, shortened) = shorten(text)
        return Attachment(kind: .photo, name: name, text: cut, shortened: shortened ? true : nil, imageFile: file)
    }

    static func scan(_ pages: [UIImage], into folder: URL) async throws -> Attachment {
        guard let first = pages.first else { throw Failure.unreadable("the scan") }
        let file = try save(downscale(first, to: 1600), into: folder)
        var texts: [String] = []
        for (i, page) in pages.enumerated() {
            let text = await recognize(downscale(page, to: 2200))
            texts.append(pages.count > 1 ? "(Page \(i + 1))\n\(text)" : text)
        }
        let (cut, shortened) = shorten(texts.joined(separator: "\n\n"))
        let name = "Scan, \(Date.now.formatted(date: .abbreviated, time: .shortened))"
        return Attachment(kind: .scan, name: name, text: cut, shortened: shortened ? true : nil,
                          imageFile: file, pages: pages.count)
    }

    static func file(_ url: URL) async throws -> Attachment {
        let name = url.lastPathComponent
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var text = ""
        var pages: Int?
        if url.pathExtension.lowercased() == "pdf" {
            guard let pdf = PDFDocument(url: url) else { throw Failure.unreadable(name) }
            text = pdf.string ?? ""
            pages = pdf.pageCount
        } else if url.pathExtension.lowercased() == "rtf",
                  let rich = try? NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                     documentAttributes: nil) {
            text = rich.string
        } else if let data = try? Data(contentsOf: url) {
            text = String(decoding: data, as: UTF8.self)
        } else {
            throw Failure.unreadable(name)
        }
        let (cut, shortened) = shorten(text)
        return Attachment(kind: .file, name: name, text: cut, shortened: shortened ? true : nil, pages: pages)
    }

    /// The picture behind an attachment, for the model to look at.
    static func cgImage(at url: URL) -> CGImage? {
        UIImage(contentsOfFile: url.path)?.cgImage
    }

    // MARK: Helpers

    /// Finds the words in a picture, on the iPhone.
    static func recognize(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { done in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                done.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            do {
                try VNImageRequestHandler(cgImage: cg, orientation: .init(image.imageOrientation)).perform([request])
            } catch {
                done.resume(returning: "")
            }
        }
    }

    private static func shorten(_ text: String) -> (String, Bool) {
        let clean = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limit = Brain.attachmentBudget
        guard clean.count > limit else { return (clean, false) }
        return (String(clean.prefix(limit)), true)
    }

    private static func downscale(_ image: UIImage, to longest: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, longest / max(size.width, size.height))
        guard scale < 1 else { return image }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }

    private static func save(_ image: UIImage, into folder: URL) throws -> String {
        let name = "\(UUID().uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: 0.82) else { throw Failure.unreadable("the picture") }
        try data.write(to: folder.appending(path: name), options: [.atomic, .completeFileProtectionUnlessOpen])
        return name
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

// MARK: - Showing attachments

/// A small square picture (or symbol) for an attachment.
struct AttachmentThumb: View {
    let attachment: Attachment
    let url: URL?
    var side: CGFloat = 44

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: attachment.symbol)
                    .font(.system(size: side * 0.42, weight: .medium))
                    .foregroundStyle(Theme.orb)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.well)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous).strokeBorder(Theme.hairline))
    }
}

/// An attachment as a card: picture, name, and what was read from it.
struct AttachmentCard: View {
    let attachment: Attachment
    let url: URL?
    var remove: (() -> Void)? = nil

    private var detail: String {
        let words = attachment.text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        var parts: [String] = []
        if let pages = attachment.pages { parts.append(pages == 1 ? "1 page" : "\(pages) pages") }
        if attachment.kind == .photo && Brain.canSee { parts.append(words > 0 ? "seen · \(words) words read" : "seen") }
        else { parts.append(words > 0 ? "\(words) words read" : "no text found") }
        if attachment.shortened == true { parts.append("shortened") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 10) {
            AttachmentThumb(attachment: attachment, url: url, side: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(Theme.ui(.footnote, .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(Theme.ui(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let remove {
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(attachment.name)")
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: 240, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline))
    }
}

/// While a picture or file is being read.
struct ReadingCard: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Reading on this iPhone…")
                .font(Theme.ui(.footnote, .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline))
    }
}

// MARK: - The document scanner

/// Apple's document camera: finds the page, flattens it, and hands back pictures.
struct DocumentScanner: UIViewControllerRepresentable {
    let done: ([UIImage]) -> Void

    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let done: ([UIImage]) -> Void
        init(done: @escaping ([UIImage]) -> Void) { self.done = done }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            done((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { done([]) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { done([]) }
    }
}
