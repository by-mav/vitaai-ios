import SwiftUI
import Foundation

// MARK: - Color Helper

extension Color {
    /// Extract RRGGBB UInt for storage (reuses existing Color(hex:) initializer).
    var vitaHex: UInt {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = UInt(max(0, min(255, r * 255)))
        let gi = UInt(max(0, min(255, g * 255)))
        let bi = UInt(max(0, min(255, b * 255)))
        return (ri << 16) | (gi << 8) | bi
    }
}
