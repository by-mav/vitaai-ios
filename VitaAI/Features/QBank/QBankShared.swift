import SwiftUI
import WebKit

// MARK: - QBank Badge

struct QBankBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
    }
}

// MARK: - HTML Text Renderer (WKWebView)

struct QBankHTMLText: UIViewRepresentable {
    let html: String
    var textColor: String = "#FFFFFF"
    var bgColor: String = "transparent"

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHtml = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: -apple-system, sans-serif;
            font-size: 15px;
            line-height: 1.5;
            color: \(textColor);
            background: \(bgColor);
            margin: 0; padding: 0;
            -webkit-text-size-adjust: none;
          }
          img { max-width: 100%; height: auto; border-radius: 8px; margin: 4px 0; }
          table { border-collapse: collapse; width: 100%; }
          td, th { border: 1px solid rgba(255,255,255,0.12); padding: 6px 8px; font-size: 12px; }
          p { margin: 0 0 8px 0; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(styledHtml, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                guard let height = result as? CGFloat else { return }
                DispatchQueue.main.async {
                    webView.frame.size.height = height
                }
            }
        }
    }
}

// MARK: - Config Screen Helpers

struct QBankSectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(VitaColors.textPrimary)
    }
}

struct QBankChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? VitaColors.accent.opacity(0.12) : VitaColors.glassBg)
                .overlay(
                    Capsule().stroke(
                        isSelected ? VitaColors.accent.opacity(0.3) : VitaColors.glassBorder,
                        lineWidth: 1
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct QBankFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

struct QBankConfigToggleRow: View {
    let icon: String
    let title: String
    let description: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isOn ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? VitaColors.accent : VitaColors.textTertiary.opacity(0.4))
            }
            .padding(12)
            .background(isOn ? VitaColors.accent.opacity(0.06) : VitaColors.glassBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn ? VitaColors.accent.opacity(0.2) : VitaColors.glassBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CGFloat clamping

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
