import SwiftUI

// MARK: - VitaButton Variants & Sizes

enum VitaButtonVariant {
    case primary
    case secondary
    case ghost
    case danger
}

enum VitaButtonSize {
    case sm
    case md
    case lg

    var height: CGFloat {
        switch self {
        case .sm: return 32
        case .md: return 44
        case .lg: return 52
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm: return 12
        case .md: return 16
        case .lg: return 24
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .sm: return 6
        case .md: return 10
        case .lg: return 14
        }
    }

    var font: Font {
        switch self {
        case .sm: return VitaTypography.labelSmall
        case .md: return VitaTypography.labelLarge
        case .lg: return VitaTypography.titleSmall
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .sm: return 16
        case .md: return 20
        case .lg: return 24
        }
    }
}

// MARK: - VitaButton

/// Unified button component for VitaAI.
///
/// Variants:
/// - `primary`   — filled accent background, dark text
/// - `secondary` — outlined with accent border, accent text
/// - `ghost`     — transparent, accent text, no border
/// - `danger`    — filled red background, white text
///
/// Sizes: `sm` (32pt), `md` (44pt), `lg` (52pt). All enforce 44pt min touch target.
struct VitaButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathing = false

    let text: String
    let action: () -> Void
    var variant: VitaButtonVariant = .primary
    var size: VitaButtonSize = .md
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var leadingSystemImage: String? = nil

    private static let dangerColor = VitaColors.dataRed
    private static let breathDuration: Double = 3.6
    private static let pressedScale: CGFloat = 0.985

    private var isInteractable: Bool { isEnabled && !isLoading }
    private var shouldBreathe: Bool {
        variant == .primary && isEnabled && !isLoading && !reduceMotion
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
    }

    private var foregroundColor: Color {
        let effective = isEnabled
        switch variant {
        case .primary:
            return effective ? VitaColors.black : VitaColors.black.opacity(0.38)
        case .secondary, .ghost:
            return effective ? VitaColors.accent : VitaColors.accent.opacity(0.38)
        case .danger:
            return effective ? VitaColors.white : VitaColors.white.opacity(0.38)
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return .clear
        case .secondary, .ghost:
            return .clear
        case .danger:
            return isEnabled ? Self.dangerColor : Self.dangerColor.opacity(0.38)
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary:
            return isEnabled
                ? VitaColors.accent.opacity(0.5)
                : VitaColors.accent.opacity(0.2)
        default:
            return .clear
        }
    }

    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                VitaColors.accentLight,
                VitaColors.accentHover,
                VitaColors.accent,
                VitaColors.accentDark
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var primaryLight: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: VitaColors.white.opacity(0.34), location: 0),
                .init(color: VitaColors.accentLight.opacity(0.18), location: 0.34),
                .init(color: VitaColors.accentHover.opacity(0.05), location: 0.62),
                .init(color: .clear, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var primaryEdge: LinearGradient {
        LinearGradient(
            colors: [
                VitaColors.white.opacity(0.52),
                VitaColors.accentLight.opacity(0.18),
                VitaColors.accentDark.opacity(0.48)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var buttonBackground: some View {
        ZStack {
            shape.fill(backgroundColor)

            if variant == .primary {
                shape
                    .fill(primaryGradient)
                    .opacity(isEnabled ? 1 : 0.38)

                shape
                    .fill(primaryLight)
                    .opacity(isEnabled ? (isBreathing ? 0.92 : 0.42) : 0.12)
            }
        }
    }

    @ViewBuilder
    private var buttonEdge: some View {
        switch variant {
        case .primary:
            shape
                .strokeBorder(primaryEdge, lineWidth: VitaTokens.Elevation.xs)
                .opacity(isEnabled ? 1 : 0.28)
        case .secondary:
            shape
                .strokeBorder(borderColor, lineWidth: VitaTokens.Elevation.xs)
        case .ghost, .danger:
            EmptyView()
        }
    }

    private var contactShadowColor: Color {
        guard variant == .primary, isEnabled else { return .clear }
        return VitaColors.black.opacity(0.48)
    }

    private var glowShadowColor: Color {
        guard variant == .primary, isEnabled else { return .clear }
        return VitaColors.accentHover.opacity(isBreathing ? 0.30 : 0.14)
    }

    var body: some View {
        Button(action: { if isInteractable { action() } }) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .frame(width: size.iconSize, height: size.iconSize)
                        .scaleEffect(size.iconSize / 20)
                } else if let icon = leadingSystemImage {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize - 2, weight: .medium))
                        .foregroundColor(foregroundColor)
                }

                Text(text)
                    .font(size.font)
                    .foregroundColor(foregroundColor)
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: max(size.height, 44))
            .background { buttonBackground }
            .clipShape(shape)
            .overlay { buttonEdge }
            .shadow(
                color: contactShadowColor,
                radius: VitaTokens.Elevation.md,
                x: 0,
                y: VitaTokens.Elevation.sm
            )
            .shadow(
                color: glowShadowColor,
                radius: VitaTokens.Elevation.xl,
                x: 0,
                y: 0
            )
        }
        .buttonStyle(VitaButtonPressStyle(
            isEnabled: isInteractable,
            pressedScale: Self.pressedScale
        ))
        .disabled(!isInteractable)
        .onAppear(perform: syncBreathing)
        .onDisappear { isBreathing = false }
        .onChange(of: shouldBreathe) { _ in syncBreathing() }
        .animation(.easeInOut(duration: 0.15), value: isInteractable)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
    }

    private func syncBreathing() {
        withAnimation(.none) {
            isBreathing = false
        }

        guard shouldBreathe else { return }
        withAnimation(
            .easeInOut(duration: Self.breathDuration)
                .repeatForever(autoreverses: true)
        ) {
            isBreathing = true
        }
    }
}

private struct VitaButtonPressStyle: ButtonStyle {
    let isEnabled: Bool
    let pressedScale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && isEnabled ? pressedScale : 1)
            .brightness(configuration.isPressed && isEnabled ? -0.04 : 0)
            .animation(
                .easeOut(duration: VitaTokens.Animation.durationFast),
                value: configuration.isPressed
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VitaButton variants") {
    VStack(spacing: 16) {
        VitaButton(text: "Primary", action: {}, variant: .primary, size: .md)
        VitaButton(text: "Secondary", action: {}, variant: .secondary, size: .md)
        VitaButton(text: "Ghost", action: {}, variant: .ghost, size: .md)
        VitaButton(text: "Danger", action: {}, variant: .danger, size: .md)
        VitaButton(text: "Loading…", action: {}, variant: .primary, size: .md, isLoading: true)
        VitaButton(text: "Disabled", action: {}, variant: .primary, size: .md, isEnabled: false)
        VitaButton(text: "With icon", action: {}, variant: .primary, size: .lg, leadingSystemImage: "arrow.right")
        HStack {
            VitaButton(text: "Sm", action: {}, variant: .secondary, size: .sm)
            VitaButton(text: "Md", action: {}, variant: .secondary, size: .md)
            VitaButton(text: "Lg", action: {}, variant: .secondary, size: .lg)
        }
    }
    .padding()
    .background(VitaColors.surface)
}
#endif
