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
    var isTyping: Bool = false
    var isReaction: Bool = false

    var body: some View {
        HStack(alignment: .bottom) {
            (Text(text)
                .font(isReaction ? VitaTypography.headlineSmall : VitaTypography.bodyLarge)
                .foregroundColor(VitaColors.textPrimary)
            + Text(isTyping ? "\u{258D}" : "")
                .font(VitaTypography.bodyMedium)
                .foregroundColor(VitaColors.accent.opacity(0.78)))
            .lineSpacing(VitaTokens.Spacing.xs)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.md)
        .frame(maxWidth: .infinity)
        .background {
            VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) { EmptyView() }
        }
        .overlay(alignment: .bottomLeading) {
            OnboardingSpeechTail()
                .fill(VitaColors.glassBg)
                .frame(width: VitaTokens.Spacing.xl, height: VitaTokens.Spacing.lg)
                .offset(x: -VitaTokens.Spacing.sm, y: VitaTokens.Spacing.sm)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingSpeechTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.width * 0.42, y: rect.height * 0.45)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.height * 0.38),
                control: CGPoint(x: rect.width * 0.50, y: rect.height * 0.78)
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
