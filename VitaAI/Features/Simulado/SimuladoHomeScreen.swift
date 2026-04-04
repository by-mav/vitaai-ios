import SwiftUI

// MARK: - Teal color palette for Simulados (matches web mockup exactly)
private enum SimuladoColors {
    // Background
    static let bg = Color(red: 0.024, green: 0.039, blue: 0.055) // #060a0e

    // Teal accent shades
    static let tealPrimary = Color(red: 0.471, green: 0.863, blue: 0.941)    // rgba(120,220,240)
    static let tealMedium = Color(red: 0.314, green: 0.784, blue: 0.863)     // rgba(80,200,220)
    static let tealDark = Color(red: 0.235, green: 0.706, blue: 0.784)       // rgba(60,180,200)
    // Section label: rgba(120,210,230,0.55) — slightly cooler than tealPrimary
    static let sectionLabel = Color(red: 0.471, green: 0.824, blue: 0.902).opacity(0.55)

    // Text
    static let textPrimary = Color.white.opacity(0.90)
    static let textSecondary = Color(red: 0.627, green: 0.863, blue: 0.941).opacity(0.45) // rgba(160,220,240,0.45)
    static let textMuted = Color(red: 0.627, green: 0.863, blue: 0.941).opacity(0.40)

    // Card
    static let cardBg = LinearGradient(
        colors: [
            Color(red: 0.024, green: 0.055, blue: 0.078).opacity(0.94),
            Color(red: 0.031, green: 0.063, blue: 0.086).opacity(0.90)
        ],
        startPoint: .top, endPoint: .bottom
    )
    static let cardBorder = Color(red: 0.314, green: 0.784, blue: 0.863).opacity(0.16) // rgba(80,200,220,0.16)

    // CTA button
    static let ctaGradient = LinearGradient(
        colors: [
            Color(red: 0.157, green: 0.627, blue: 0.706).opacity(0.7),
            Color(red: 0.118, green: 0.471, blue: 0.588).opacity(0.5)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Badges
    static let badgeDoneBg = Color(red: 0.235, green: 0.706, blue: 0.471).opacity(0.15)
    static let badgeDoneText = Color(red: 0.471, green: 0.863, blue: 0.627).opacity(0.85)
    static let badgeDoneBorder = Color(red: 0.235, green: 0.706, blue: 0.471).opacity(0.20)

    static let badgeProgressBg = Color(red: 0.784, green: 0.627, blue: 0.235).opacity(0.15)
    static let badgeProgressText = Color(red: 0.941, green: 0.784, blue: 0.392).opacity(0.85)
    static let badgeProgressBorder = Color(red: 0.784, green: 0.627, blue: 0.235).opacity(0.20)
}

// MARK: - SimuladoHomeScreen

struct SimuladoHomeScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoViewModel?
    let onBack: () -> Void
    let onNewSimulado: () -> Void
    let onOpenSession: (String) -> Void
    let onOpenResult: (String) -> Void
    let onOpenDiagnostics: () -> Void

    var body: some View {
        Group {
            if let vm {
                homeContent(vm: vm)
            } else {
                ZStack {
                    SimuladoColors.bg.ignoresSafeArea()
                    ProgressView().tint(SimuladoColors.tealPrimary)
                }
            }
        }
        .onAppear {
            if vm == nil { vm = SimuladoViewModel(api: container.api, gamificationEvents: container.gamificationEvents) }
            vm?.loadAttempts()
        }
    }

    @ViewBuilder
    private func homeContent(vm: SimuladoViewModel) -> some View {
        ZStack {
            // Background image
            Image("bg-simulados")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Dark overlay gradient matching web
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.016, green: 0.031, blue: 0.055).opacity(0.3), location: 0),
                    .init(color: Color(red: 0.016, green: 0.031, blue: 0.055).opacity(0.1), location: 0.4),
                    .init(color: Color(red: 0.016, green: 0.031, blue: 0.055).opacity(0.5), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if vm.state.isLoading {
                ProgressView().tint(SimuladoColors.tealPrimary)
            } else if vm.state.attempts.isEmpty {
                emptyState
            } else {
                scrollContent(vm: vm)
            }
        }
        .navigationBarHidden(true)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(SimuladoColors.tealPrimary.opacity(0.4))
            Text("Nenhum simulado ainda")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SimuladoColors.textPrimary)
            Text("Comece seu primeiro simulado para testar seus conhecimentos.")
                .font(.system(size: 13))
                .foregroundStyle(SimuladoColors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: onNewSimulado) {
                Text("Começar primeiro simulado")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SimuladoColors.ctaGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: SimuladoColors.tealDark.opacity(0.25), radius: 12, y: 8)
            }
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    @ViewBuilder
    private func scrollContent(vm: SimuladoViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Stats hero card
                SimuladoStatsHero(stats: vm.state.stats)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // CTA button
                Button(action: onNewSimulado) {
                    Text("Novo Simulado")
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .tracking(-0.15)
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(SimuladoColors.ctaGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(alignment: .top) {
                            // inset 0 1px 0 rgba(120,220,240,0.20) — top inner highlight
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [SimuladoColors.tealPrimary.opacity(0.20), .clear],
                                        startPoint: .top, endPoint: .init(x: 0.5, y: 0.08)
                                    )
                                )
                                .frame(height: 4)
                        }
                        .shadow(color: SimuladoColors.tealDark.opacity(0.25), radius: 12, y: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // "RECENTES" section label
                HStack {
                    Text("Recentes")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SimuladoColors.sectionLabel)
                        .tracking(0.5)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Attempt cards
                ForEach(vm.state.filteredAttempts) { attempt in
                    SimuladoAttemptCard(attempt: attempt) {
                        if attempt.status == "finished" { onOpenResult(attempt.id) }
                        else { onOpenSession(attempt.id) }
                    }
                    .padding(.horizontal, 16)
                    .contextMenu {
                        Button(role: .destructive) {
                            vm.deleteAttempt(attempt.id)
                        } label: {
                            Label("Apagar", systemImage: "trash")
                        }
                        Button {
                            vm.archiveAttempt(attempt.id)
                        } label: {
                            Label("Arquivar", systemImage: "archivebox")
                        }
                    }
                }

                // Diagnostic link
                Button(action: onOpenDiagnostics) {
                    HStack(spacing: 8) {
                        // 3-bar chart: left short, center tall, right medium (matches web SVG M18 20V10, M12 20V4, M6 20v-6)
                        SimuladoBarChartIcon()
                            .frame(width: 16, height: 16)
                        Text("Ver diagnóstico completo")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(SimuladoColors.tealPrimary.opacity(0.70))
                    .padding(.vertical, 12)
                }
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
        }
    }
}

// MARK: - Stats Hero Card

private struct SimuladoStatsHero: View {
    let stats: SimuladoStats

    private var avgPercent: String {
        let pct = stats.avgScore * 100
        if pct == pct.rounded() {
            return "\(Int(pct))%"
        }
        return String(format: "%.1f%%", pct)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Big score
            Text(avgPercent)
                .font(.system(size: 48, weight: .heavy))
                .tracking(-1.9)
                .foregroundStyle(SimuladoColors.tealPrimary.opacity(0.92))
                .padding(.top, 22)

            Text("Score médio")
                .font(.system(size: 12))
                .foregroundStyle(SimuladoColors.textMuted)
                .tracking(0.5)
                .padding(.top, 4)

            // Stats row
            HStack(spacing: 24) {
                SimuladoMiniStat(value: "\(stats.completedAttempts)", label: "Simulados")
                SimuladoMiniStat(value: "\(stats.totalQuestions)", label: "Questões")
                SimuladoMiniStat(value: "\(stats.totalCorrect)", label: "Acertos")
            }
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .background(SimuladoTealGlassBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(SimuladoColors.cardBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.50), radius: 25, y: 20)
        .shadow(color: SimuladoColors.tealDark.opacity(0.09), radius: 14, y: 0)
    }
}

private struct SimuladoMiniStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.88))
            Text(label)
                .font(.system(size: 9.5, weight: .regular))
                .foregroundStyle(SimuladoColors.textMuted)
                .tracking(0.4)
                .textCase(.uppercase)
        }
    }
}

// MARK: - Attempt Card

private struct SimuladoAttemptCard: View {
    let attempt: SimuladoAttemptEntry
    let onTap: () -> Void

    private var isFinished: Bool { attempt.status == "finished" }
    private var scoreDisplay: String {
        if isFinished {
            return "\(Int(attempt.score * 100))%"
        }
        return "\(attempt.correctQ)/\(attempt.totalQ)"
    }

    private var dateDisplay: String {
        guard let raw = attempt.startedAt, raw.count >= 10 else { return "" }
        let parts = String(raw.prefix(10)).split(separator: "-")
        guard parts.count == 3 else { return "" }
        let months = ["", "jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
        let day = String(parts[2])
        if let monthInt = Int(parts[1]), monthInt > 0, monthInt <= 12 {
            return "\(day) \(months[monthInt])"
        }
        return "\(day)/\(parts[1])"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    SimuladoColors.tealDark.opacity(0.22),
                                    SimuladoColors.tealDark.opacity(0.10)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(SimuladoColors.cardBorder, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 3)

                    Image(systemName: isFinished ? "checkmark.square" : "clock")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SimuladoColors.tealPrimary.opacity(0.85))
                }
                .frame(width: 40, height: 40)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(attempt.title.isEmpty ? (attempt.subject ?? "Simulado") : attempt.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SimuladoColors.textPrimary)
                        .lineLimit(1)
                    Text("\(attempt.totalQ) questões · \(dateDisplay)")
                        .font(.system(size: 10))
                        .foregroundStyle(SimuladoColors.textMuted)
                }

                Spacer(minLength: 4)

                // Score + badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(scoreDisplay)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SimuladoColors.tealPrimary.opacity(0.90))

                    Text(isFinished ? "Concluído" : "Em andamento")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            isFinished ? SimuladoColors.badgeDoneBg : SimuladoColors.badgeProgressBg
                        )
                        .foregroundStyle(
                            isFinished ? SimuladoColors.badgeDoneText : SimuladoColors.badgeProgressText
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isFinished ? SimuladoColors.badgeDoneBorder : SimuladoColors.badgeProgressBorder,
                                    lineWidth: 1
                                )
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(SimuladoTealGlassBackground())
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(SimuladoColors.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.50), radius: 25, y: 20)
            .shadow(color: SimuladoColors.tealDark.opacity(0.06), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
    }
}

// MARK: - Bar Chart Icon (matches web SVG: left=short, center=tall, right=medium)

private struct SimuladoBarChartIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let barW: CGFloat = w * 0.14
            let gap = (w - barW * 3) / 4
            let color = GraphicsContext.Shading.color(SimuladoColors.tealPrimary.opacity(0.85))
            // Left bar: 30% height
            let leftH = h * 0.30
            ctx.fill(Path(CGRect(x: gap, y: h - leftH, width: barW, height: leftH).insetBy(dx: -0.5, dy: 0)), with: color)
            // Center bar: 80% height (tallest)
            let midH = h * 0.80
            ctx.fill(Path(CGRect(x: gap * 2 + barW, y: h - midH, width: barW, height: midH)), with: color)
            // Right bar: 50% height
            let rightH = h * 0.50
            ctx.fill(Path(CGRect(x: gap * 3 + barW * 2, y: h - rightH, width: barW, height: rightH)), with: color)
        }
    }
}

// MARK: - Teal Glass Background (3-layer matching web)

private struct SimuladoTealGlassBackground: View {
    var body: some View {
        ZStack {
            // Layer 1: base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.024, green: 0.055, blue: 0.078).opacity(0.94),
                    Color(red: 0.031, green: 0.063, blue: 0.086).opacity(0.90)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Layer 2: corner radial lights (inner glow)
            ZStack {
                // Bottom-left glow
                RadialGradient(
                    colors: [SimuladoColors.tealDark.opacity(0.18), .clear],
                    center: .bottomLeading, startRadius: 0, endRadius: 120
                )
                // Bottom-right glow
                RadialGradient(
                    colors: [SimuladoColors.tealDark.opacity(0.12), .clear],
                    center: .bottomTrailing, startRadius: 0, endRadius: 120
                )
                // Top-left glow
                RadialGradient(
                    colors: [SimuladoColors.tealDark.opacity(0.09), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 100
                )
                // Top-right glow
                RadialGradient(
                    colors: [SimuladoColors.tealDark.opacity(0.06), .clear],
                    center: .topTrailing, startRadius: 0, endRadius: 100
                )
            }

            // Layer 3: top highlight line
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, SimuladoColors.tealPrimary.opacity(0.12), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, SimuladoColors.tealDark.opacity(0.08), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
        }
    }
}
