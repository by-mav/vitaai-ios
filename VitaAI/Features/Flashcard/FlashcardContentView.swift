import SwiftUI

// MARK: - FlashcardContentView
//
// Renders flashcard content that may contain HTML <img> tags (AnKing deck format).
// Strategy:
//   1. If no <img> tags → plain Text() (zero overhead)
//   2. If img tags present → split into segments, render text via markdown + images via AsyncImage
//
// Text segments support: **bold**, *italic*, bullet lists, numbered lists.

struct FlashcardContentView: View {
    let content: String
    let fontSize: CGFloat
    let textColor: Color
    let alignment: TextAlignment

    init(
        content: String,
        fontSize: CGFloat = 16,
        textColor: Color = VitaColors.white.opacity(0.88),
        alignment: TextAlignment = .leading
    ) {
        self.content = content
        self.fontSize = fontSize
        self.textColor = textColor
        self.alignment = alignment
    }

    private var segments: [ContentSegment] {
        ContentSegmentParser.parse(content)
    }

    private var hasImages: Bool {
        segments.contains { if case .image = $0 { return true }; return false }
    }

    var body: some View {
        if !hasImages {
            // Fast path — plain text, no parsing overhead
            Text(content)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(textColor)
                .multilineTextAlignment(alignment)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        } else {
            // Mixed content — text + inline images
            VStack(alignment: alignment == .center ? .center : .leading, spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    segmentView(segment)
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        }
    }

    @ViewBuilder
    private func segmentView(_ segment: ContentSegment) -> some View {
        switch segment {
        case .text(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                FlashcardTextSegment(
                    text: trimmed,
                    fontSize: fontSize,
                    textColor: textColor,
                    alignment: alignment
                )
            }

        case .image(let url):
            FlashcardImageSegment(url: url)
        }
    }
}

// MARK: - Text Segment (markdown-aware)

private struct FlashcardTextSegment: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let alignment: TextAlignment

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        let hasListItems = lines.contains { isListItem($0) }

        if hasListItems {
            listView(lines: lines)
        } else {
            // Single paragraph — inline markdown spans
            Text(renderInline(text))
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(textColor)
                .multilineTextAlignment(alignment)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        }
    }

    @ViewBuilder
    private func listView(lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty { EmptyView() }
                else if let (bullet, itemText) = unorderedItem(trimmedLine) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(bullet)
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundStyle(textColor.opacity(0.6))
                        Text(renderInline(itemText))
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundStyle(textColor)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if let (num, itemText) = orderedItem(trimmedLine) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(num).")
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundStyle(textColor.opacity(0.6))
                            .frame(minWidth: 20, alignment: .trailing)
                        Text(renderInline(itemText))
                            .font(.system(size: fontSize, weight: .medium))
                            .foregroundStyle(textColor)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(renderInline(trimmedLine))
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(alignment)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isListItem(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return unorderedItem(t) != nil || orderedItem(t) != nil
    }

    private func unorderedItem(_ line: String) -> (String, String)? {
        if line.hasPrefix("- ") { return ("-", String(line.dropFirst(2))) }
        if line.hasPrefix("* ") { return ("•", String(line.dropFirst(2))) }
        if line.hasPrefix("+ ") { return ("+", String(line.dropFirst(2))) }
        return nil
    }

    private func orderedItem(_ line: String) -> (Int, String)? {
        let pattern = /^(\d+)\.\s+(.+)/
        if let match = try? pattern.wholeMatch(in: line) {
            return (Int(match.output.1) ?? 0, String(match.output.2))
        }
        return nil
    }

    /// Converts basic markdown inline syntax to AttributedString.
    private func renderInline(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Bold: **text**
            if remaining.hasPrefix("**"),
               let endIdx = findMarker("**", in: remaining.dropFirst(2)) {
                let inner = String(remaining.dropFirst(2).prefix(upTo: endIdx))
                var s = AttributedString(inner)
                s.font = .system(size: fontSize, weight: .bold)
                s.foregroundColor = Color.white.opacity(0.95)
                result.append(s)
                remaining = remaining.dropFirst(2)[endIdx...].dropFirst(2)
                continue
            }

            // Italic: *text* or _text_
            if remaining.hasPrefix("*"),
               !remaining.hasPrefix("**"),
               let endIdx = findChar("*", in: remaining.dropFirst(1)) {
                let inner = String(remaining.dropFirst(1).prefix(upTo: endIdx))
                var s = AttributedString(inner)
                s.font = .system(size: fontSize, weight: .medium).italic()
                s.foregroundColor = textColor
                result.append(s)
                remaining = remaining.dropFirst(1)[endIdx...].dropFirst(1)
                continue
            }
            if remaining.hasPrefix("_"),
               let endIdx = findChar("_", in: remaining.dropFirst(1)) {
                let inner = String(remaining.dropFirst(1).prefix(upTo: endIdx))
                var s = AttributedString(inner)
                s.font = .system(size: fontSize, weight: .medium).italic()
                s.foregroundColor = textColor
                result.append(s)
                remaining = remaining.dropFirst(1)[endIdx...].dropFirst(1)
                continue
            }

            // Plain character
            var s = AttributedString(String(remaining.removeFirst()))
            s.font = .system(size: fontSize, weight: .medium)
            s.foregroundColor = textColor
            result.append(s)
        }

        return result
    }

    private func findMarker(_ marker: String, in sub: Substring) -> Substring.Index? {
        var idx = sub.startIndex
        while idx < sub.endIndex {
            if sub[idx...].hasPrefix(marker) { return idx }
            idx = sub.index(after: idx)
        }
        return nil
    }

    private func findChar(_ ch: Character, in sub: Substring) -> Substring.Index? {
        sub.firstIndex(of: ch)
    }
}

// MARK: - Image Segment

private struct FlashcardImageSegment: View {
    let url: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Cap image height so it never overflows the card container.
    // iPhone: 200pt max. iPad (regular width): 300pt max.
    private var maxImageHeight: CGFloat {
        horizontalSizeClass == .regular ? 300 : 200
    }

    var body: some View {
        if let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    // Placeholder shimmer
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.06))
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .overlay(
                            ProgressView()
                                .tint(Color(red: 148/255, green: 75/255, blue: 220/255))
                        )

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: maxImageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                case .failure:
                    // Broken image indicator
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .overlay(
                            HStack(spacing: 6) {
                                Image(systemName: "photo.badge.exclamationmark")
                                    .foregroundStyle(Color.white.opacity(0.25))
                                Text("Imagem indisponível")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.25))
                            }
                        )

                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Content Segment Parser

private enum ContentSegment {
    case text(String)
    case image(url: String)
}

private enum ContentSegmentParser {
    // Matches <img src="..." ...> and <img src='...' ...>
    // Also handles self-closing />
    private static let imgPattern = /<img[^>]*\bsrc=["']([^"']+)["'][^>]*\/?>/

    static func parse(_ input: String) -> [ContentSegment] {
        // Quick bail-out — no img tags
        guard input.contains("<img") else {
            return [.text(input)]
        }

        var segments: [ContentSegment] = []
        var searchRange = input.startIndex..<input.endIndex
        var cursor = input.startIndex

        for match in input.matches(of: imgPattern) {
            let matchStart = match.range.lowerBound
            let matchEnd = match.range.upperBound
            let imgURL = String(match.output.1)

            // Text before this image
            if cursor < matchStart {
                let textChunk = String(input[cursor..<matchStart])
                let stripped = stripOtherHTML(textChunk)
                if !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(.text(stripped))
                }
            }

            segments.append(.image(url: imgURL))
            cursor = matchEnd
        }

        // Remaining text after last image
        if cursor < input.endIndex {
            let textChunk = String(input[cursor...])
            let stripped = stripOtherHTML(textChunk)
            if !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.text(stripped))
            }
        }

        return segments.isEmpty ? [.text(input)] : segments
    }

    /// Strips non-img HTML tags from a text chunk (e.g. <br>, <div>, <b>, etc.)
    /// Converts <br> → newline, <b>/<strong> → ** markdown, <i>/<em> → * markdown.
    private static func stripOtherHTML(_ text: String) -> String {
        var result = text

        // <br> and <br/> → newline
        result = result.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)

        // <b>text</b> and <strong>text</strong> → **text**
        result = result.replacingOccurrences(of: "<(b|strong)>", with: "**", options: .regularExpression)
        result = result.replacingOccurrences(of: "</(b|strong)>", with: "**", options: .regularExpression)

        // <i>text</i> and <em>text</em> → *text*
        result = result.replacingOccurrences(of: "<(i|em)>", with: "*", options: .regularExpression)
        result = result.replacingOccurrences(of: "</(i|em)>", with: "*", options: .regularExpression)

        // <ul>/<ol>/<li> → newline + bullet
        result = result.replacingOccurrences(of: "<li>", with: "\n- ", options: .regularExpression)
        result = result.replacingOccurrences(of: "</li>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "</?[uo]l>", with: "", options: .regularExpression)

        // Strip remaining HTML tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode basic HTML entities
        result = result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")

        return result
    }
}
