import SwiftUI

enum SubjectColors {

    // MARK: - Presets (16 colors)

    static let presets: [Color] = [
        VitaColors.accentHover,
        VitaTokens.PrimitiveColors.cyan400,
        VitaTokens.PrimitiveColors.indigo400,
        VitaTokens.PrimitiveColors.green400,
        VitaTokens.PrimitiveColors.orange400,
        VitaTokens.PrimitiveColors.red400,
        VitaTokens.PrimitiveColors.teal400,
        VitaTokens.PrimitiveColors.amber400,
        Color(hex: 0xE91E63),  // Pink
        Color(hex: 0x9C27B0),  // Purple
        Color(hex: 0x3F51B5),  // Deep Indigo
        Color(hex: 0x00BCD4),  // Deep Cyan
        Color(hex: 0x8BC34A),  // Light Green
        Color(hex: 0xFF5722),  // Deep Orange
        Color(hex: 0x795548),  // Brown
        Color(hex: 0x607D8B),  // Blue Grey
    ]

    // Backwards compat
    static let palette = presets

    // MARK: - Color resolution

    static func colorFor(subject: String) -> Color {
        if let custom = customColor(for: subject) { return custom }
        var sum: UInt32 = 0
        for byte in subject.utf8 { sum = (sum &* 31) &+ UInt32(byte) }
        return presets[Int(sum) % presets.count]
    }

    // MARK: - Custom color persistence

    private static let storageKey = "vita_subject_custom_colors"

    static func customColor(for subject: String) -> Color? {
        guard
            let dict = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String],
            let hexStr = dict[subject],
            let hex = UInt(hexStr, radix: 16)
        else { return nil }
        return Color(hex: hex)
    }

    static func setCustomColor(_ color: Color, for subject: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]) ?? [:]
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let hex = String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        dict[subject] = hex
        UserDefaults.standard.set(dict, forKey: storageKey)
    }

    static func resetColor(for subject: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]) ?? [:]
        dict.removeValue(forKey: subject)
        UserDefaults.standard.set(dict, forKey: storageKey)
    }

    // MARK: - Hex string to Color (for hex input field)

    static func color(fromHexString hex: String) -> Color? {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard clean.count == 6, let value = UInt(clean, radix: 16) else { return nil }
        return Color(hex: value)
    }
}
