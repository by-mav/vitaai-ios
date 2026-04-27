import SwiftUI

/// Portal connector icon — dynamic, source-agnostic.
///
/// Renders the visual identifier of the portal that originated a notification
/// (or anything else attributed to a connector). Three fallback layers:
///
/// 1. Remote `iconUrl` from backend metadata (resolved server-side from
///    `portal_types.icon_url`) — async-loaded with disk cache.
/// 2. Bundled asset `mascot-<source>` (manually shipped per connector) —
///    same pattern used in ConnectionsScreen for known integrations.
/// 3. Last resort: circle with the first letter of the source slug, tinted
///    by `brandColor` (also from server-side metadata) when present, else
///    neutral gold.
///
/// Added 2026-04-27 — companion to backend `portal-notify.ts` helper.
/// SaaS-friendly: 300+ connectors don't need client code changes — just add
/// the row in `vita.portal_types` (icon URL or mascot asset) and it shows up.
struct PortalIcon: View {
    let source: String?              // 'canvas', 'mannesoft', 'sigaa', ... or nil for vita-internal
    var iconUrl: String? = nil       // remote logo (preferred when present)
    var brandColor: String? = nil    // hex like '#1CB0F6' — colors the placeholder
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let urlString = iconUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                    default:
                        bundledOrLetter
                    }
                }
            } else {
                bundledOrLetter
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }

    @ViewBuilder
    private var bundledOrLetter: some View {
        if let source, let assetImage = Self.bundledAsset(for: source) {
            assetImage.resizable().scaledToFit()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(placeholderFill)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .stroke(placeholderStroke, lineWidth: 0.6)
                )
            if let source, !source.isEmpty {
                Text(String(source.prefix(1)).uppercased())
                    .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                    .foregroundStyle(placeholderText)
            } else {
                // Vita-internal notif (no portal source): small mascot vibe via dot
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(VitaColors.accentHover.opacity(0.85))
            }
        }
    }

    // MARK: - Color resolution

    private var placeholderFill: Color {
        if let hex = brandColor, let c = Color(hex: hex) {
            return c.opacity(0.22)
        }
        return VitaColors.accentHover.opacity(0.16)
    }

    private var placeholderStroke: Color {
        if let hex = brandColor, let c = Color(hex: hex) {
            return c.opacity(0.30)
        }
        return VitaColors.accentHover.opacity(0.22)
    }

    private var placeholderText: Color {
        if let hex = brandColor, let c = Color(hex: hex) {
            return c.opacity(0.95)
        }
        return VitaColors.accentHover.opacity(0.90)
    }

    // MARK: - Bundled asset lookup

    /// Map portal slug → bundled `mascot-<slug>` Image. Returns nil if asset
    /// not in bundle — caller falls back to the letter placeholder.
    private static func bundledAsset(for source: String) -> Image? {
        let key = "mascot-\(source.replacingOccurrences(of: "_", with: "-"))"
        if UIImage(named: key) != nil {
            return Image(key)
        }
        return nil
    }
}

// MARK: - Color hex helper (local)

private extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
