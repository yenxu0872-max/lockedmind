// The light markdown the model is asked to write — headings, bullets,
// numbered steps, bold, inline code and fenced code — drawn as native text.
// It copes with half-written input, since replies are drawn as they stream.

import SwiftUI
import UIKit

enum Block: Equatable {
    case heading(Int, String)
    case paragraph(String)
    case list([Item])
    case code(language: String, text: String)
    case quote(String)
    case rule

    struct Item: Equatable {
        var marker: String       // "•" or "1."
        var text: String
        var depth: Int
    }
}

enum Markdown {
    static func blocks(_ source: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var items: [Block.Item] = []
        var code: (language: String, lines: [String])?

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
            if !items.isEmpty { blocks.append(.list(items)); items = [] }
        }

        for raw in source.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if var open = code {
                if line.hasPrefix("```") { blocks.append(.code(language: open.language, text: open.lines.joined(separator: "\n"))); code = nil }
                else { open.lines.append(raw); code = open }
                continue
            }
            if line.hasPrefix("```") {
                flush()
                code = (String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces), [])
                continue
            }
            if line.isEmpty { flush(); continue }
            if ["-", "*", "•", "—", "–"].contains(line) { continue }    // a stray mark on its own line
            if let level = heading(line) {
                flush()
                blocks.append(.heading(level, String(line.drop { $0 == "#" }).trimmingCharacters(in: .whitespaces)))
                continue
            }
            if ["---", "***", "___"].contains(line) { flush(); blocks.append(.rule); continue }
            if line.hasPrefix(">") {
                flush()
                blocks.append(.quote(String(line.dropFirst()).trimmingCharacters(in: .whitespaces)))
                continue
            }
            let depth = min(2, raw.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) } / 2)
            if let (marker, text) = listItem(line) {
                if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
                items.append(.init(marker: marker, text: text, depth: depth))
                continue
            }
            if !items.isEmpty { items[items.count - 1].text += " " + line; continue }   // a wrapped list item
            paragraph.append(line)
        }
        if let open = code { blocks.append(.code(language: open.language, text: open.lines.joined(separator: "\n"))) }
        flush()
        return blocks
    }

    private static func heading(_ line: String) -> Int? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return hashes
    }

    private static func listItem(_ line: String) -> (String, String)? {
        for bullet in ["- ", "* ", "• ", "+ "] where line.hasPrefix(bullet) {
            return ("•", String(line.dropFirst(2)))
        }
        let digits = line.prefix { $0.isNumber }
        if !digits.isEmpty, digits.count <= 3 {
            let rest = line.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") { return ("\(digits).", String(rest.dropFirst(2))) }
        }
        return nil
    }

    /// Bold, italics, inline code and links. A stray `**` from a reply still
    /// being written is hidden rather than shown.
    static func inline(_ text: String) -> AttributedString {
        var source = text
        if source.components(separatedBy: "**").count % 2 == 0, let last = source.range(of: "**", options: .backwards) {
            source.removeSubrange(last)
        }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace,
                                                              failurePolicy: .returnPartiallyParsedIfPossible)
        guard var out = try? AttributedString(markdown: source, options: options) else { return AttributedString(text) }
        // Inline code in Geist Mono, on a faint wash.
        for run in out.runs where run.inlinePresentationIntent?.contains(.code) == true {
            out[run.range].font = Theme.mono(.callout, .medium)
            out[run.range].backgroundColor = Theme.violet.opacity(0.12)
        }
        return out
    }
}

/// A reply, drawn like a page: Geist text, the orb's colours for bullets and
/// step numbers, Geist Mono for code.
struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(Array(Markdown.blocks(text).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .font(Theme.answer)
        .lineSpacing(3.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func view(for block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(Markdown.inline(text))
                .font(Theme.ui(level <= 2 ? .title3 : .headline, .semibold))
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(Markdown.inline(text))
        case .list(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(item.marker)
                            .font(Theme.ui(.body, item.marker == "•" ? .black : .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.orb)
                            .frame(minWidth: 18, alignment: .trailing)
                        Text(Markdown.inline(item.text))
                    }
                    .padding(.leading, CGFloat(item.depth) * 18)
                }
            }
        case .code(let language, let text):
            CodeBlock(language: language, code: text)
        case .quote(let text):
            HStack(spacing: 12) {
                Capsule().fill(Theme.thread).frame(width: 3)
                Text(Markdown.inline(text)).italic().foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .rule:
            Divider().padding(.vertical, 4)
        }
    }
}

struct CodeBlock: View {
    let language: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "code" : language.lowercased())
                    .font(Theme.mono(.caption, .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(Theme.ui(.caption, .medium))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(Theme.mono(.footnote))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline))
    }
}
