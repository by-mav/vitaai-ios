import SwiftUI

// MARK: - OnboardingStep Enum

enum OnboardingStep: Int, CaseIterable {
    case sleep = 0
    // Kept at a new raw value so existing AppStorage values remain compatible.
    // Declaration order is intentional: sleep -> introduction -> academic phase.
    case introduction = 13
    // Onda 5b (Rafael 2026-04-27) — fork por journeyType (REVALIDA/RESIDENCIA/ENAMED/FACULDADE/INTERNATO).
    // statusFaculdade + goal sao SEMPRE mostrados (P2 + P1 do onboarding v2).
    // revalidaStage so aparece se goal=REVALIDA. welcome/connect so se inFaculdade=yes.
    case statusFaculdade = 1
    // New value preserves every historical AppStorage raw value.
    case phaseResponse = 14
    case goal = 2
    case revalidaStage = 3
    case residenciaSpecialty = 12  // Slice 4: so se goal=RESIDENCIA. Numero alto pra nao quebrar AppStorage migration legacy.
    case welcome = 4
    case connect = 5
    case extras = 6           // WhatsApp, Google Drive, Calendar, Spotify — tudo opcional
    case syncing = 7
    case subjects = 8
    case notifications = 9
    case trial = 10
    case done = 11
}

// MARK: - Speech Bubble

struct OnboardingSpeechBubble: View {
    let text: String
    var reservedText: String? = nil
    var isTyping: Bool = false
    var isReaction: Bool = false

    private var finalText: String { reservedText ?? text }

    private func speechText(_ value: String, showCursor: Bool) -> Text {
        Text(value)
            .font(isReaction ? VitaTypography.headlineSmall : VitaTypography.bodyLarge)
            .foregroundColor(VitaColors.textPrimary)
        + Text(showCursor ? "\u{258D}" : "")
            .font(VitaTypography.bodyMedium)
            .foregroundColor(VitaColors.accent.opacity(0.78))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Reserve the completed copy from the first frame. The glass keeps
            // its final geometry while only the visible characters progress.
            speechText(finalText, showCursor: false)
                .lineSpacing(VitaTokens.Spacing.xs)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .accessibilityHidden(true)

            speechText(text, showCursor: isTyping)
                .lineSpacing(VitaTokens.Spacing.xs)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) { EmptyView() }
        }
        .background(alignment: .bottomLeading) {
            OnboardingSpeechTail()
                .fill(VitaColors.glassBg)
                .overlay {
                    OnboardingSpeechTail()
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                }
                .frame(width: VitaTokens.Spacing._4xl, height: VitaTokens.Spacing._3xl)
                .offset(x: -VitaTokens.Spacing._2xl, y: VitaTokens.Spacing.md)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Canonical Vita speech composition

/// The single source of truth for every conversational onboarding step.
/// The bubble owns its mascot anchor and motion so screens never guess offsets.
struct OnboardingVitaSpeech: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let text: String
    let reservedText: String
    let mascotNamespace: Namespace.ID
    var usesWakeTransition: Bool = false
    var showsBubble: Bool = true
    var isTyping: Bool = false
    var isReaction: Bool = false
    var mascotState: VitaMascotState = .happy
    var mascotScale: CGFloat = 1
    var mascotBlushing: Bool = false

    @State private var isPresented = false

    var body: some View {
        HStack(alignment: .bottom, spacing: -VitaTokens.Spacing.sm) {
            // A measured, non-negotiable column prevents the mascot and its
            // oversized aura from ever consuming the bubble's text region.
            ZStack(alignment: .bottom) {
                speakingMascot
            }
            .frame(width: 76, height: 76, alignment: .bottom)
            // OrbMascot deliberately paints a 2.2x atmospheric canvas around
            // its 64pt body. This measured compensation aligns the visible
            // sphere (not the invisible aura canvas) with the bubble tail.
            .offset(y: 96)
            .zIndex(1)

            OnboardingSpeechBubble(
                text: text,
                reservedText: reservedText,
                isTyping: isTyping,
                isReaction: isReaction
            )
            .opacity(showsBubble && isPresented ? 1 : 0)
            .scaleEffect(
                showsBubble && (isPresented || reduceMotion) ? 1 : 0.985,
                anchor: .bottomLeading
            )
            .allowsHitTesting(showsBubble)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // The visible orb intentionally hangs below the bubble. Reserve that
        // footprint so the first control of the next section can never sit
        // underneath the mascot.
        .padding(.bottom, VitaTokens.Spacing._3xl)
        .task(id: "\(reservedText)|\(showsBubble)") {
            isPresented = false
            guard showsBubble else { return }
            await Task.yield()
            if reduceMotion {
                isPresented = true
            } else {
                withAnimation(.easeOut(duration: 0.22)) {
                    isPresented = true
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var speakingMascot: some View {
        let mascot = VitaMascot(
            state: mascotState,
            size: 64,
            idleEnabled: true,
            isBlushing: mascotBlushing,
            showsOrbit: false
        )
        .scaleEffect(mascotScale)

        if usesWakeTransition {
            mascot.matchedGeometryEffect(
                id: "onboarding-speaking-mascot",
                in: mascotNamespace,
                properties: .frame,
                anchor: .center,
                isSource: false
            )
        } else {
            mascot
        }
    }
}

// MARK: - Canonical onboarding input

/// Every value typed during onboarding uses this exact control. Keeping the
/// field local to the flow avoids drifting university, token and code inputs.
struct OnboardingTextInput: View {
    @Binding var value: String
    var label: String? = nil
    let placeholder: String
    var leadingSystemImage: String? = nil
    var errorMessage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .done
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrectionDisabled = false
    var showClearButton = true
    var accessibilityIdentifier: String? = nil
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    private var borderColor: Color {
        if errorMessage != nil { return VitaColors.dataRed.opacity(0.8) }
        if isFocused { return VitaColors.accent.opacity(0.78) }
        return VitaColors.accent.opacity(0.28)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
            if let label {
                Text(label)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textSecondary)
            }

            HStack(spacing: VitaTokens.Spacing.md) {
                if let leadingSystemImage {
                    Image(systemName: leadingSystemImage)
                        .font(VitaTypography.titleLarge)
                        .foregroundStyle(isFocused ? VitaColors.accent : VitaColors.textSecondary)
                        .frame(width: 22)
                }

                TextField(placeholder, text: $value)
                    .font(VitaTypography.bodyLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                    .tint(VitaColors.accent)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(autocorrectionDisabled)
                    .submitLabel(submitLabel)
                    .focused($isFocused)
                    .accessibilityIdentifier(accessibilityIdentifier ?? "")
                    .onSubmit { onSubmit?() }

                if showClearButton && !value.isEmpty {
                    Button {
                        value = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(VitaTypography.titleMedium)
                            .foregroundStyle(VitaColors.textTertiary)
                            .frame(width: 32, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "onboarding_a11y_clear_field"))
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .frame(minHeight: 56)
            .background {
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                    .fill(VitaColors.surfaceElevated.opacity(0.78))
            }
            .overlay {
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused ? 1.25 : 1)
            }
            .shadow(
                color: isFocused ? VitaColors.accent.opacity(0.16) : .black.opacity(0.18),
                radius: isFocused ? 16 : 8,
                y: isFocused ? 4 : 3
            )
            .animation(.easeInOut(duration: 0.18), value: isFocused)

            if let errorMessage {
                Text(errorMessage)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.dataRed)
                    .padding(.leading, VitaTokens.Spacing.sm)
            }
        }
    }
}

// MARK: - Canonical onboarding choice

struct OnboardingChoiceRow: View {
    let title: String
    var subtitle: String? = nil
    let systemImage: String
    let isSelected: Bool
    var accessibilityIdentifier: String = ""
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: VitaTokens.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                        .fill(isSelected ? VitaColors.accent.opacity(0.14) : VitaColors.glassBg)
                        .frame(width: 34, height: 34)
                    Image(systemName: systemImage)
                        .font(PixioTypo.body)
                        .foregroundStyle(
                            isSelected
                                ? VitaColors.accent
                                : VitaColors.textPrimary.opacity(0.52)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VitaTypography.labelLarge)
                        .foregroundStyle(
                            isSelected
                                ? VitaColors.textPrimary
                                : VitaColors.textPrimary.opacity(0.82)
                        )
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textTertiary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: VitaTokens.Spacing.sm)

                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? VitaColors.accent : VitaColors.textTertiary.opacity(0.7),
                            lineWidth: 1.25
                        )
                        .frame(width: 19, height: 19)
                    if isSelected {
                        Circle()
                            .fill(VitaColors.accent)
                            .frame(width: 9, height: 9)
                    }
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .fill(isSelected ? VitaColors.accent.opacity(0.09) : VitaColors.glassBg)
            }
            .overlay {
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .stroke(
                        isSelected ? VitaColors.accent.opacity(0.42) : VitaColors.glassBorder,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct OnboardingSpeechTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.08))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.width * 0.62, y: rect.height * 0.62)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.height * 0.46),
                control: CGPoint(x: rect.width * 0.48, y: rect.height * 0.86)
            )
            path.closeSubpath()
        }
    }
}

// MARK: - Progress Dots

struct OnboardingProgressDots: View {
    var currentStep: Int
    var totalDots: Int = 5

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalDots, id: \.self) { i in
                Circle()
                    .fill(i <= currentStep ? VitaColors.accent.opacity(0.7) : Color.white.opacity(0.08))
                    .frame(width: 8, height: 8)
                    .shadow(color: i <= currentStep ? VitaColors.accent.opacity(0.3) : .clear, radius: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }
}

// MARK: - Starfield (enhanced with nebula)

struct OnboardingStarfieldLayer: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Nebula glow (subtle teal/gold)
            RadialGradient(
                colors: [
                    Color(red: 0.15, green: 0.85, blue: 0.75).opacity(0.03),
                    VitaColors.accent.opacity(0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.3, y: 0.3),
                startRadius: 50,
                endRadius: 400
            )

            // Stars
            Canvas { context, size in
                for i in 0..<50 {
                    let x = CGFloat((i * 31 + 11) % 100) / 100.0 * size.width
                    let y = CGFloat((i * 23 + 7) % 100) / 100.0 * size.height
                    let r = CGFloat(1 + (i * 7) % 3) * (i % 5 == 0 ? 0.8 : 0.4)
                    let opacity = 0.15 + (i % 4 == 0 ? 0.15 : 0.0)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(VitaColors.accent.opacity(opacity))
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - ENAMED Badge (reusable)

struct ENAMEDBadge: View {
    let score: Int

    private var badgeColor: Color {
        score >= 4 ? VitaColors.dataGreen : score >= 3 ? VitaColors.accent : .white.opacity(0.4)
    }

    var body: some View {
        HStack(spacing: 2) {
            Text("ENAMED")
                .font(.system(size: 7, weight: .bold))
            Text("\(score)")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.08))
        )
    }
}
