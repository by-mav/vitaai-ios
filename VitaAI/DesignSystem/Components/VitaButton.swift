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
        case .sm: return VitaTypography.buttonSmall
        case .md: return VitaTypography.buttonMedium
        case .lg: return VitaTypography.buttonLarge
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .sm: return 14
        case .md: return 16
        case .lg: return 18
        }
    }
}

// MARK: - Canonical primary CTA material

/// Shared physical palette for every primary Vita CTA. The surface stays dark;
/// only its rim and ambient halo breathe.
struct VitaCTAChromePalette {
    let foreground: Color
    let tint: Color
    let highlight: Color
    let rim: Color
    let glow: Color

    static let gold = VitaCTAChromePalette(
        foreground: VitaColors.accentLight.opacity(0.92),
        tint: VitaColors.accent,
        highlight: VitaColors.accentLight,
        rim: VitaColors.accentHover,
        glow: VitaColors.accent
    )
}

private struct VitaPrimaryCTAChrome: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var isBreathing = false

    let palette: VitaCTAChromePalette
    let cornerRadius: CGFloat
    let visualEnabled: Bool?
    let breathingEnabled: Bool

    private static let breathDuration: Double = 3.8

    private var effectiveEnabled: Bool { visualEnabled ?? isEnabled }
    private var shouldBreathe: Bool {
        effectiveEnabled && breathingEnabled && !reduceMotion
    }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(palette.foreground)
            .background {
                ZStack {
                    shape.fill(VitaColors.glassBg)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                palette.highlight.opacity(0.10),
                                palette.tint.opacity(0.11),
                                VitaColors.surfaceCard.opacity(0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            palette.highlight.opacity(isBreathing ? 0.78 : 0.50),
                            palette.rim.opacity(isBreathing ? 0.34 : 0.20),
                            palette.rim.opacity(isBreathing ? 0.66 : 0.40)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: VitaTokens.Elevation.xs * 0.75
                )
            }
            .shadow(
                color: VitaColors.black.opacity(effectiveEnabled ? 0.34 : 0),
                radius: VitaTokens.Elevation.md,
                x: 0,
                y: VitaTokens.Elevation.sm
            )
            .background {
                shape
                    .fill(palette.glow.opacity(
                        effectiveEnabled ? (isBreathing ? 0.21 : 0.11) : 0
                    ))
                    .padding(VitaTokens.Spacing.xs)
                    .blur(radius: VitaTokens.Elevation._2xl)
                    .allowsHitTesting(false)
            }
            .opacity(effectiveEnabled ? 1 : 0.42)
            .onAppear(perform: syncBreathing)
            .onDisappear { isBreathing = false }
            .onChange(of: shouldBreathe) { _ in syncBreathing() }
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

extension View {
    func vitaPrimaryCTAChrome(
        palette: VitaCTAChromePalette = .gold,
        cornerRadius: CGFloat = VitaTokens.Radius.full,
        visualEnabled: Bool? = nil,
        breathingEnabled: Bool = true
    ) -> some View {
        modifier(VitaPrimaryCTAChrome(
            palette: palette,
            cornerRadius: cornerRadius,
            visualEnabled: visualEnabled,
            breathingEnabled: breathingEnabled
        ))
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
    let text: String
    let action: () -> Void
    var variant: VitaButtonVariant = .primary
    var size: VitaButtonSize = .md
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var leadingSystemImage: String? = nil
    var trailingSystemImage: String? = nil
    var fillsWidth: Bool = false

    private static let dangerColor = VitaColors.dataRed
    private var isInteractable: Bool { isEnabled && !isLoading }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
    }

    private var foregroundColor: Color {
        let effective = isEnabled
        switch variant {
        case .primary:
            return effective
                ? VitaCTAChromePalette.gold.foreground
                : VitaCTAChromePalette.gold.foreground.opacity(0.38)
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

    @ViewBuilder
    private var buttonEdge: some View {
        switch variant {
        case .secondary:
            shape
                .strokeBorder(borderColor, lineWidth: VitaTokens.Elevation.xs)
        case .primary, .ghost, .danger:
            EmptyView()
        }
    }

    private var labelContent: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                    .frame(width: size.iconSize, height: size.iconSize)
                    .scaleEffect(size.iconSize / 20)
            } else if let icon = leadingSystemImage {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .medium))
                    .foregroundColor(foregroundColor)
            }

            Text(text)
                .font(size.font)
                .tracking(VitaTokens.Typography.letterSpacingWide * 0.5)
                .foregroundColor(foregroundColor)

            if !isLoading, let icon = trailingSystemImage {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .medium))
                    .foregroundColor(foregroundColor)
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(maxWidth: fillsWidth ? .infinity : nil)
        .frame(minHeight: max(size.height, 44))
    }

    @ViewBuilder
    private var styledLabel: some View {
        if variant == .primary {
            labelContent
                .vitaPrimaryCTAChrome(
                    visualEnabled: isEnabled,
                    breathingEnabled: !isLoading
                )
        } else {
            labelContent
                .background(backgroundColor)
                .clipShape(shape)
                .overlay { buttonEdge }
        }
    }

    var body: some View {
        Button(action: { if isInteractable { action() } }) {
            styledLabel
        }
        .buttonStyle(VitaButtonPressStyle(isEnabled: isInteractable))
        .disabled(!isInteractable)
        .animation(.easeInOut(duration: 0.15), value: isInteractable)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
    }
}

struct VitaButtonPressStyle: ButtonStyle {
    var isEnabled: Bool = true
    var pressedScale: CGFloat = 0.985

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
