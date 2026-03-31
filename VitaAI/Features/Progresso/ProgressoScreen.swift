import SwiftUI

// MARK: - ProgressoScreen (matches progresso-mobile-v1.html mockup pixel-perfect)
// Uses MOCK DATA matching exact mockup values. Real API data will replace later.

struct ProgressoScreen: View {
    @Environment(\.appContainer) private var container

    // Gold palette from VitaColors
    private let goldPrimary = VitaColors.accentHover
    private let goldMuted   = VitaColors.accentLight
    private let textPrimary = VitaColors.textPrimary
    private let textSec     = VitaColors.textSecondary
    private let textDim     = VitaColors.textTertiary
    private let greenStat   = Color(red: 0.51, green: 0.784, blue: 0.549) // rgba(130,200,140)
    private let glassBg     = VitaColors.glassBg
    private let glassBorder = VitaColors.glassBorder

    @State private var vm: ProgressoViewModel?
    @State private var selectedLeaderboardTab = 0

    // ── MOCK DATA (matches mockup exactly) ──
    private let mockLevel = 7
    private let mockCurrentXp = 740
    private let mockTotalXp = 1000
    private let mockStreakDays = 4
    private let mockTodayWeekdayIdx = 3 // Thursday (0=Mon)
    private let mockStudyHours = "23h"
    private let mockAccuracy = "78%"
    private let mockFlashcards = "324"
    private let mockWeeklyActual = 8.5
    private let mockWeeklyGoal = 14.0
    private let mockWeeklyBars: [Double] = [0.50, 0.70, 0.35, 0.85, 0, 0, 0]

    private let mockWeakAreas: [(name: String, image: String, meta: String, pct: Int, color: Color)] = [
        ("Farmacologia", "disc-farmacologia", "47 questoes \u{00B7} 12h estudo", 52,
         Color(red: 1.0, green: 0.471, blue: 0.314)), // rgba(255,120,80)
        ("Patologia", "disc-patologia-geral", "23 questoes \u{00B7} 8h estudo", 61,
         Color(red: 1.0, green: 0.784, blue: 0.392)), // rgba(255,200,100)
        ("Histologia", "disc-histologia", "35 questoes \u{00B7} 6h estudo", 68,
         Color(red: 1.0, green: 0.784, blue: 0.392))  // rgba(255,200,100)
    ]

    private let mockLeaderboard: [(rank: Int, initials: String, name: String, xp: String, isMe: Bool)] = [
        (1, "MG", "Maria Garcia",   "2.340 XP", false),
        (2, "JS", "Joao Santos",    "1.890 XP", false),
        (3, "CP", "Camila Pereira", "1.120 XP", false),
        (4, "AL", "Ana Lima",       "980 XP",   false),
        (5, "LM", "Lucas Martins",  "820 XP",   false)
    ]
    private let mockMyEntry = (rank: 8, initials: "RF", name: "Rafael Freitas", xp: "740 XP")

    // Heatmap mock: 91 cells matching mockup pattern
    private let mockHeatmap: [Int] = [
        0,1,0,2,1,0,3,1,0,2,4,2,1,
        1,0,1,3,2,1,0,2,3,1,2,3,4,
        0,2,1,0,1,2,3,1,4,2,3,4,3,
        1,0,2,1,3,2,1,3,2,4,3,2,4,
        0,1,0,2,1,3,2,4,3,2,4,3,4,
        1,2,1,3,2,4,3,2,4,3,2,4,3,
        2,1,3,2,4,3,4,3,4,2,3,4,3
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                heroCard
                statsGrid
                weeklyChart
                weakAreasSection
                leaderboardSection
                heatmapSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .refreshable {
            if let vm { await vm.load() }
        }
        .task {
            if vm == nil {
                vm = ProgressoViewModel(api: container.api)
            }
        }
    }

    // MARK: - Hero Card (XP ring + name + XP bar + streak)

    private var heroCard: some View {
        let levelRatio = Double(mockCurrentXp) / Double(mockTotalXp)

        return glassCard {
            HStack(spacing: 16) {
                // XP Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: levelRatio)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.784, blue: 0.392).opacity(0.90),
                                    Color(red: 0.784, green: 0.588, blue: 0.235).opacity(0.70)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.20), radius: 6)

                    Text("\(mockLevel)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(goldMuted.opacity(0.95))
                        .tracking(-0.5)

                    // XP badge below ring
                    Text("\(mockCurrentXp) XP")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(goldMuted.opacity(0.95))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            VitaColors.accent.opacity(0.35),
                                            VitaColors.accentDark.opacity(0.25)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(goldMuted.opacity(0.30), lineWidth: 1)
                        )
                        .offset(y: 40)
                }
                .frame(width: 72, height: 72)

                // Info column
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.authManager.userName ?? "Rafael Freitas")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.3)

                    Text("\(mockCurrentXp) / \(mockTotalXp) XP para nivel \(mockLevel + 1)")
                        .font(.system(size: 11))
                        .foregroundStyle(textSec)

                    // XP bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 4)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            VitaColors.accent.opacity(0.70),
                                            goldPrimary.opacity(0.50)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * levelRatio, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 6)

                    // Streak dots
                    streakRow
                        .padding(.top, 10)
                }
            }
            .padding(18)
        }
    }

    // MARK: - Streak Row

    private var streakRow: some View {
        let labels = ["S", "T", "Q", "Q", "S", "S", "D"]
        let todayIdx = mockTodayWeekdayIdx

        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { idx in
                let isOn = idx < todayIdx
                let isNow = idx == todayIdx
                streakDay(labels[idx], isOn: isOn, isNow: isNow)
            }
        }
    }

    private func streakDay(_ label: String, isOn: Bool, isNow: Bool) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(
                isNow
                    ? goldMuted.opacity(0.95)
                    : isOn
                        ? goldMuted.opacity(0.90)
                        : VitaColors.textWarm.opacity(0.25)
            )
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isNow
                            ? VitaColors.glassInnerLight.opacity(0.25)
                            : isOn
                                ? VitaColors.glassInnerLight.opacity(0.12)
                                : Color.white.opacity(0.02)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isNow
                            ? goldPrimary.opacity(0.30)
                            : isOn
                                ? goldPrimary.opacity(0.18)
                                : VitaColors.textWarm.opacity(0.04),
                        lineWidth: 1
                    )
            )
            .shadow(color: isNow ? VitaColors.glassInnerLight.opacity(0.15) : .clear, radius: 4)
    }

    // MARK: - Stats Grid 2x2

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            statCard(icon: "chart.bar.fill", value: "\(mockStreakDays)", label: "Dias streak",
                     valueColor: goldMuted.opacity(0.90))
            statCard(icon: "clock.fill", value: mockStudyHours, label: "Estudo total",
                     valueColor: goldMuted.opacity(0.90))
            statCard(icon: "checkmark.square.fill", value: mockAccuracy, label: "Acerto medio",
                     valueColor: greenStat.opacity(0.85))
            statCard(icon: "rectangle.stack.fill", value: mockFlashcards, label: "Flashcards",
                     valueColor: goldMuted.opacity(0.90))
        }
    }

    private func statCard(icon: String, value: String, label: String, valueColor: Color) -> some View {
        glassCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VitaColors.glassInnerLight.opacity(0.25),
                                        VitaColors.accentDark.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(goldPrimary.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 5)

                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(valueColor)
                        .tracking(-0.3)
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Esta semana")

            glassCard {
                VStack(spacing: 12) {
                    // Header: "8.5h de 14h" + "Meta semanal"
                    HStack {
                        Text(String(format: "%.1f", mockWeeklyActual) + "h de \(Int(mockWeeklyGoal))h")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                        Spacer()
                        Text("Meta semanal")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                    }

                    // Bar chart
                    HStack(alignment: .bottom, spacing: 8) {
                        let labels = ["S", "T", "Q", "Q", "S", "S", "D"]
                        ForEach(0..<7, id: \.self) { idx in
                            barColumn(
                                label: labels[idx],
                                heightFraction: mockWeeklyBars[idx],
                                isToday: idx == mockTodayWeekdayIdx
                            )
                        }
                    }
                    .frame(height: 90)
                }
                .padding(14)
            }
        }
    }

    private func barColumn(label: String, heightFraction: CGFloat, isToday: Bool) -> some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)

            // Bar with top-rounded, bottom-less-rounded corners (6,6,2,2)
            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 2,
                bottomTrailingRadius: 2,
                topTrailingRadius: 6
            )
            .fill(
                isToday
                    ? LinearGradient(
                        colors: [
                            VitaColors.accent.opacity(0.70),
                            goldPrimary.opacity(0.50)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                      )
                    : LinearGradient(
                        colors: [
                            VitaColors.accent.opacity(0.35),
                            VitaColors.accent.opacity(0.15)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                      )
            )
            .frame(height: max(heightFraction * 76, heightFraction > 0 ? 4 : 0))
            .shadow(
                color: isToday ? VitaColors.accent.opacity(0.18) : .clear,
                radius: 6,
                y: -2
            )

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(
                    isToday
                        ? goldMuted.opacity(0.70)
                        : VitaColors.textWarm.opacity(0.28)
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weak Areas ("Onde melhorar")

    private var weakAreasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Onde melhorar")

            glassCard {
                VStack(spacing: 0) {
                    ForEach(Array(mockWeakAreas.enumerated()), id: \.offset) { idx, area in
                        weakAreaRow(
                            image: area.image,
                            name: area.name,
                            meta: area.meta,
                            pct: area.pct,
                            color: area.color
                        )
                        if idx < mockWeakAreas.count - 1 {
                            dividerLine
                        }
                    }
                }
            }
        }
    }

    private func weakAreaRow(image: String, name: String, meta: String, pct: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text(meta)
                    .font(.system(size: 10))
                    .foregroundStyle(textSec)
            }

            Spacer()

            // Mini progress bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 48, height: 4)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.65), color.opacity(0.40)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 48 * CGFloat(pct) / 100.0, height: 4)
            }

            Text("\(pct)%")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color.opacity(0.75))
                .frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.04))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Ranking")

            glassCard {
                VStack(spacing: 0) {
                    // Tabs
                    HStack(spacing: 4) {
                        lbTab("Semanal", index: 0)
                        lbTab("Mensal", index: 1)
                        lbTab("Total", index: 2)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    // Top 5
                    ForEach(Array(mockLeaderboard.enumerated()), id: \.offset) { idx, entry in
                        lbRow(
                            rank: entry.rank,
                            initials: entry.initials,
                            name: entry.name,
                            xp: entry.xp,
                            rankColor: rankColorForPosition(entry.rank),
                            avatarBg: avatarColorForPosition(entry.rank),
                            isMe: entry.isMe
                        )
                        if idx < mockLeaderboard.count - 1 {
                            lbDivider
                        }
                    }

                    // Gold separator
                    Rectangle()
                        .fill(goldPrimary.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)

                    // "Sua posicao" label
                    HStack {
                        Text("SUA POSICAO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.25))
                            .tracking(0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 2)

                    // My entry
                    lbRow(
                        rank: mockMyEntry.rank,
                        initials: mockMyEntry.initials,
                        name: mockMyEntry.name,
                        xp: mockMyEntry.xp,
                        rankColor: goldMuted.opacity(0.80),
                        avatarBg: goldPrimary,
                        isMe: true
                    )

                    // "Ver ranking completo" button
                    Button {
                        // Navigation to full leaderboard
                    } label: {
                        Text("Ver ranking completo")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(goldMuted.opacity(0.55))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(goldPrimary.opacity(0.10), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func lbTab(_ text: String, index: Int) -> some View {
        Button {
            selectedLeaderboardTab = index
        } label: {
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(
                    selectedLeaderboardTab == index
                        ? goldMuted.opacity(0.85)
                        : VitaColors.textWarm.opacity(0.35)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            selectedLeaderboardTab == index
                                ? VitaColors.glassInnerLight.opacity(0.12)
                                : Color.white.opacity(0.02)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            selectedLeaderboardTab == index
                                ? goldPrimary.opacity(0.18)
                                : VitaColors.textWarm.opacity(0.06),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func lbRow(rank: Int, initials: String, name: String, xp: String, rankColor: Color, avatarBg: Color, isMe: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(rankColor)
                .frame(width: 22)

            Text(initials)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VitaColors.textWarm.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [avatarBg.opacity(0.30), avatarBg.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    isMe
                        ? goldMuted.opacity(0.90)
                        : Color.white.opacity(0.85)
                )

            Spacer()

            Text(xp)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(goldMuted.opacity(0.70))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isMe
                ? AnyShapeStyle(VitaColors.glassInnerLight.opacity(0.06))
                : AnyShapeStyle(.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var lbDivider: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.04))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Ultimos 91 dias")

            glassCard {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 13)

                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<mockHeatmap.count, id: \.self) { i in
                        Rectangle()
                            .fill(heatmapColor(mockHeatmap[i]))
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .padding(14)
            }
        }
    }

    private func heatmapColor(_ level: Int) -> Color {
        switch level {
        case 1: return VitaColors.accent.opacity(0.15)
        case 2: return VitaColors.accent.opacity(0.30)
        case 3: return VitaColors.accent.opacity(0.48)
        case 4: return VitaColors.accent.opacity(0.65)
        default: return Color.white.opacity(0.03)
        }
    }

    // MARK: - Shared Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(glassBg)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(glassBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.40), radius: 20, y: 8)
    }

    private func rankColorForPosition(_ rank: Int) -> Color {
        switch rank {
        case 1: return goldMuted.opacity(0.90)
        case 2: return Color(red: 0.784, green: 0.784, blue: 0.824).opacity(0.70)
        case 3: return Color(red: 0.706, green: 0.549, blue: 0.392).opacity(0.65)
        default: return textDim
        }
    }

    private func avatarColorForPosition(_ rank: Int) -> Color {
        switch rank {
        case 1: return goldPrimary
        case 2: return Color(red: 0.784, green: 0.784, blue: 0.824)
        case 3: return Color(red: 0.706, green: 0.549, blue: 0.392)
        default: return Color.white
        }
    }
}
