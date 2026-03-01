import SwiftUI

extension View {
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
    }
}
