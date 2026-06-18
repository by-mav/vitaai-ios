import SwiftUI
import UIKit

// MARK: - Gamification Event Manager
// Central hub for XP toasts, level up, and badge unlock overlays.
// Registered in AppContainer, used as global overlay in AppRouter.

@MainActor @Observable
final class GamificationEventManager {
    // Uses the existing VitaXpToastState from DesignSystem
    let xpToast = VitaXpToastState()

    var levelUpEvent: LevelUpEvent?
    var badgeEvent: BadgeUnlockEvent?

    /// Current level from server — single source of truth for top bar and all UI
    var currentLevel: Int = 1
    var currentXpProgress: Double = 0

    struct LevelUpEvent: Identifiable {
        let id = UUID()
        let newLevel: Int
    }

    struct BadgeUnlockEvent: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let icon: String

        init(name: String, description: String = "", icon: String = "medal") {
            self.name = name
            self.description = description
            self.icon = icon
        }
    }

    /// Update level/XP from gamification stats response
    func updateFromStats(_ stats: GamificationStatsResponse) {
        currentLevel = max(1, stats.level)
        let total = stats.currentLevelXp + stats.xpToNextLevel
        currentXpProgress = total > 0 ? Double(stats.currentLevelXp) / Double(total) : 0
    }

    /// Process the response from POST /api/activity
    func handleActivityResponse(_ data: LogActivityResponse, previousLevel: Int?) {
        currentLevel = max(1, data.level)
        let total = data.currentLevelXp + data.xpToNextLevel
        currentXpProgress = total > 0 ? Double(data.currentLevelXp) / Double(total) : 0

        if data.xpAwarded > 0 {
            let source = XpSource.dailyLogin // generic — the toast shows XP amount
            xpToast.show(XpEvent(amount: data.xpAwarded, source: source))
        }

        if let prev = previousLevel, data.level > prev {
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                levelUpEvent = LevelUpEvent(newLevel: data.level)
            }
        }

        for badge in data.newBadges {
            Task {
                let delay: Double = (previousLevel != nil && data.level > previousLevel!) ? 5.5 : 2.2
                try? await Task.sleep(for: .seconds(delay))
                badgeEvent = BadgeUnlockEvent(name: badge.name)
            }
        }
    }
}

// MARK: - Cores por capítulo (mirror de gamification.ts — 5 seções de 20 níveis).
// SOT real = backend; ProgressoScreen.tiers carrega os MESMOS valores. Usado aqui
// pra a celebração herdar a cor do "mundo" onde o user upou.
enum VitaSectionColors {
    static let palette: [(bright: Color, mid: Color, dark: Color)] = [
        (Color(red: 0.95, green: 0.74, blue: 0.42), Color(red: 0.80, green: 0.58, blue: 0.30), Color(red: 0.42, green: 0.28, blue: 0.12)),
        (Color(red: 0.50, green: 0.88, blue: 0.66), Color(red: 0.20, green: 0.64, blue: 0.44), Color(red: 0.06, green: 0.29, blue: 0.20)),
        (Color(red: 0.52, green: 0.76, blue: 1.0),  Color(red: 0.24, green: 0.52, blue: 0.88), Color(red: 0.07, green: 0.23, blue: 0.50)),
        (Color(red: 0.80, green: 0.64, blue: 1.0),  Color(red: 0.56, green: 0.40, blue: 0.88), Color(red: 0.29, green: 0.17, blue: 0.56)),
        (Color(red: 1.0,  green: 0.80, blue: 0.52), Color(red: 0.87, green: 0.40, blue: 0.38), Color(red: 0.45, green: 0.12, blue: 0.16)),
    ]
    static func forLevel(_ l: Int) -> (bright: Color, mid: Color, dark: Color) {
        palette[min(max((l - 1) / 20, 0), palette.count - 1)]
    }
}

// MARK: - Level Up Overlay (celebração de marco — "Parabéns! Nível X")
// Juice (spec F5): dim+blur, pop com mola/overshoot, glow burst, confete na cor
// da seção, haptic .success, dismiss imediato (tap ou auto). Marco "grande" a
// cada 5 níveis (novo ícone da trilha) ganha confete extra + dura mais.

struct VitaLevelUpOverlay: View {
    let event: GamificationEventManager.LevelUpEvent?
    @State private var visible = false
    @State private var pop: CGFloat = 0.3
    @State private var glow = false
    @State private var burst = false

    private var theme: (bright: Color, mid: Color, dark: Color) {
        VitaSectionColors.forLevel(event?.newLevel ?? 1)
    }
    private var isMilestone: Bool { ((event?.newLevel ?? 0) % 5) == 0 }

    var body: some View {
        // vita-modals-ignore: custom-animation-overlay (auto-dismiss level-up celebration)
        ZStack {
            if visible, let ev = event {
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    .overlay(Color.black.opacity(0.45).ignoresSafeArea())
                    .onTapGesture { dismiss() }

                if burst {
                    ConfettiBurst(colors: [theme.bright, theme.mid, .white, theme.bright])
                        .ignoresSafeArea().allowsHitTesting(false)
                }

                VStack(spacing: 20) {
                    ZStack {
                        // glow burst (luz explodindo na cor da seção)
                        Circle()
                            .fill(RadialGradient(colors: [theme.bright.opacity(0.55), theme.mid.opacity(0.22), .clear],
                                                 center: .center, startRadius: 4, endRadius: 160))
                            .frame(width: 300, height: 300)
                            .scaleEffect(glow ? 1.18 : 0.6)
                            .opacity(glow ? 1 : 0.3)
                            .blendMode(.plusLighter)

                        // medalhão 3D do nível (mesma física de luz da trilha)
                        ZStack {
                            Circle().fill(theme.dark).frame(width: 128, height: 128).offset(y: 6)
                            Circle().fill(
                                LinearGradient(colors: [theme.bright, theme.mid, theme.dark], startPoint: .top, endPoint: .bottom)
                                    .shadow(.inner(color: .black.opacity(0.25), radius: 5, y: -3))
                            ).frame(width: 128, height: 128)
                            Ellipse().fill(.white.opacity(0.42)).frame(width: 66, height: 26)
                                .offset(y: -36).blur(radius: 4).blendMode(.plusLighter)
                            Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.85), theme.dark.opacity(0.3)],
                                                                 startPoint: .top, endPoint: .bottom), lineWidth: 2)
                                .frame(width: 128, height: 128)
                            Text("\(ev.newLevel)")
                                .font(.system(size: 50, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: theme.dark.opacity(0.7), radius: 2, y: 1)
                        }
                        .shadow(color: .black.opacity(0.5), radius: 18, y: 12)
                        .shadow(color: theme.mid.opacity(0.6), radius: 30)
                        .scaleEffect(pop)
                    }

                    VStack(spacing: 6) {
                        Text(isMilestone ? "MARCO ALCANÇADO" : "SUBIU DE NÍVEL")
                            .font(.system(size: 12, weight: .black)).tracking(3)
                            .foregroundStyle(theme.bright)
                        Text("Parabéns! Você alcançou o nível \(ev.newLevel)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(min(Double(pop), 1))
                    .scaleEffect(pop > 0.85 ? 1 : 0.92)
                }
                .padding(40)
            }
        }
        .animation(.easeOut(duration: 0.3), value: visible)
        .onChange(of: event?.id) { _ in trigger() }
    }

    private func trigger() {
        guard event != nil else { return }
        pop = 0.3; glow = false; burst = false
        visible = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.52)) { pop = 1 }   // overshoot
        withAnimation(.easeOut(duration: 0.9)) { glow = true }
        burst = true
        Task {
            try? await Task.sleep(for: .seconds(isMilestone ? 4.2 : 3.0))
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.3)) { visible = false }
        burst = false
    }
}

// MARK: - Confete (Canvas + TimelineView, sem dependência externa)

private struct ConfettiBurst: View {
    let colors: [Color]
    @State private var start = Date()
    private let pieces: [Piece] = (0..<90).map { _ in Piece.random() }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            Canvas { ctx, size in
                for p in pieces {
                    let life = t - p.delay
                    guard life > 0 else { continue }
                    let y = (life * p.speed).truncatingRemainder(dividingBy: size.height + 80) - 40
                    let x = p.x * size.width + sin(life * p.wobbleSpeed) * p.wobble
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(life * p.spin))
                    let rect = CGRect(x: -p.size / 2, y: -p.size * 0.3, width: p.size, height: p.size * 0.6)
                    c.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(p.color(colors)))
                }
            }
        }
    }

    struct Piece {
        let x, delay, speed, wobble, wobbleSpeed, size, spin: Double
        let ci: Int
        func color(_ cs: [Color]) -> Color { cs[ci % cs.count].opacity(0.92) }
        static func random() -> Piece {
            Piece(x: .random(in: 0...1), delay: .random(in: 0...0.6), speed: .random(in: 130...320),
                  wobble: .random(in: 12...64), wobbleSpeed: .random(in: 2...6),
                  size: .random(in: 6...13), spin: .random(in: 2...7), ci: .random(in: 0...3))
        }
    }
}

#Preview("Level Up — marco") {
    ZStack {
        Color.black.ignoresSafeArea()
        VitaLevelUpOverlay(event: .init(newLevel: 10))
    }
}

// MARK: - Badge Unlock Overlay

struct VitaBadgeUnlockOverlay: View {
    let event: GamificationEventManager.BadgeUnlockEvent?
    @State private var visible = false
    @State private var emojiScale: CGFloat = 0

    private static let badgeEmoji: [String: String] = [
        "school": "\u{1F393}", "style": "\u{1F0CF}", "auto_awesome": "\u{2728}",
        "emoji_events": "\u{1F3C6}", "menu_book": "\u{1F4DA}",
        "local_fire_department": "\u{1F525}", "whatshot": "\u{1F525}",
        "military_tech": "\u{1F396}\u{FE0F}", "trending_up": "\u{1F4C8}",
        "workspace_premium": "\u{1F48E}", "edit_note": "\u{1F4DD}",
        "dark_mode": "\u{1F989}", "wb_sunny": "\u{1F305}",
        "sports_esports": "\u{1F3AE}", "chat": "\u{1F4AC}",
    ]

    var body: some View {
        // vita-modals-ignore: custom-animation-overlay (auto-dismiss badge unlock celebration)
        ZStack {
            if visible, let ev = event {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [VitaColors.accent.opacity(0.25), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 130, height: 130)

                        Text(Self.badgeEmoji[ev.icon] ?? "\u{1F3C5}")
                            .font(.system(size: 56))
                            .scaleEffect(emojiScale)
                    }

                    VStack(spacing: 4) {
                        Text("CONQUISTA DESBLOQUEADA")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VitaColors.accent)
                            .tracking(2)

                        Text(ev.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Text(ev.description)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: visible)
        .onChange(of: event?.id) { _ in
            guard event != nil else { return }
            emojiScale = 0
            visible = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                emojiScale = 1
            }
            Task {
                try? await Task.sleep(for: .seconds(3.5))
                visible = false
            }
        }
    }
}
