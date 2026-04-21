import SwiftUI

// MARK: - ProgressoScreen (connected to real API via ProgressoViewModel)

struct ProgressoScreen: View {
    @Environment(\.appContainer) private var container

    // Gold palette from VitaColors
    private let goldPrimary = VitaColors.accentHover
    private let goldMuted   = VitaColors.accentLight
    private let textPrimary = VitaColors.textPrimary
    private let textSec     = VitaColors.textSecondary
    private let textDim     = VitaColors.textTertiary
    private let greenStat   = Color(red: 0.51, green: 0.784, blue: 0.549)
    private let glassBg     = VitaColors.glassBg
    private let glassBorder = VitaColors.glassBorder

    @State private var vm: ProgressoViewModel?
    @State private var selectedLeaderboardTab = 0

    var body: some View {
        Group {
            if let vm {
                if vm.isLoading {
                    ProgressView()
                        .tint(goldMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = vm.error {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(textDim)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(textSec)
                            .multilineTextAlignment(.center)
                        Button("Tentar novamente") {
                            Task { await vm.load() }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(goldMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content(vm: vm)
                }
            } else {
                ProgressView()
                    .tint(goldMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .refreshable {
            if let vm { await vm.load() }
        }
        .task {
            if vm == nil {
                let viewModel = ProgressoViewModel(api: container.api)
                vm = viewModel
                await viewModel.load()
                ScreenLoadContext.finish(for: "Progresso")
            }
        }
        .trackScreen("Progresso")
    }

    private func content(vm: ProgressoViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                heroCard(vm: vm)
                statsGrid(vm: vm)
                weeklyChart(vm: vm)
                if !vm.subjects.isEmpty {
                    weakAreasSection(vm: vm)
                }
                leaderboardSection(vm: vm)
                if !vm.heatmap.isEmpty {
                    heatmapSection(vm: vm)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Hero Card (XP ring + name + XP bar + streak)

    private func heroCard(vm: ProgressoViewModel) -> some View {
        let level = vm.userProgress?.level ?? 1
        let currentXp = vm.userProgress?.currentLevelXp ?? vm.userProgress?.totalXp ?? 0
        let xpToNext = vm.userProgress?.xpToNextLevel ?? 100
        let totalXp = vm.userProgress?.totalXp ?? 0
        let levelRatio = xpToNext > 0 ? Double(currentXp) / Double(xpToNext) : 0

        return glassCard {
            HStack(spacing: 16) {
                // XP Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: min(levelRatio, 1.0))
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

                    Text("\(level)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(goldMuted.opacity(0.95))
                        .tracking(-0.5)

                    // XP badge below ring
                    Text("\(totalXp) XP")
                        .font(.system(size: 10, weight: .bold))
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
                    Text(container.authManager.userName ?? "Estudante")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.3)

                    Text("\(currentXp) / \(xpToNext) XP para nível \(level + 1)")
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
                                .frame(width: geo.size.width * min(levelRatio, 1.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 6)

                    // Streak dots
                    streakRow(vm: vm)
                        .padding(.top, 10)
                }
            }
            .padding(18)
        }
    }

    // MARK: - Streak Row

    private func streakRow(vm: ProgressoViewModel) -> some View {
        let labels = ["S", "T", "Q", "Q", "S", "S", "D"]
        let calendar = Calendar.current
        // weekday: 1=Sunday, convert to 0=Monday index
        let rawWeekday = calendar.component(.weekday, from: Date())
        let todayIdx = (rawWeekday + 5) % 7 // Mon=0, Tue=1, ..., Sun=6

        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { idx in
                let isOn = idx < min(vm.streakDays, todayIdx)
                let isNow = idx == todayIdx
                streakDay(labels[idx], isOn: isOn, isNow: isNow)
            }
        }
    }

    private func streakDay(_ label: String, isOn: Bool, isNow: Bool) -> some View {
        let fgColor: Color = isNow ? goldMuted.opacity(0.95) : isOn ? goldMuted.opacity(0.90) : VitaColors.textWarm.opacity(0.25)
        let bgColor: Color = isNow ? VitaColors.glassInnerLight.opacity(0.25) : isOn ? VitaColors.glassInnerLight.opacity(0.12) : Color.white.opacity(0.02)
        let borderColor: Color = isNow ? goldPrimary.opacity(0.30) : isOn ? goldPrimary.opacity(0.18) : VitaColors.textWarm.opacity(0.04)
        let shadowColor: Color = isNow ? VitaColors.glassInnerLight.opacity(0.15) : .clear

        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(fgColor)
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: 8).fill(bgColor))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
            .shadow(color: shadowColor, radius: 4)
    }

    // MARK: - Stats Grid 2x2

    private func statsGrid(vm: ProgressoViewModel) -> some View {
        let studyHoursText = vm.totalStudyHours < 1
            ? "\(Int(vm.totalStudyHours * 60))min"
            : String(format: "%.0fh", vm.totalStudyHours)
        let accuracyText = "\(Int(vm.avgAccuracy * 100))%"
        let flashcardsText = "\(vm.totalQuestions)" // totalAnswered from API

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            statCard(icon: "chart.bar.fill", value: "\(vm.streakDays)", label: "Dias streak",
                     valueColor: goldMuted.opacity(0.90))
            statCard(icon: "clock.fill", value: studyHoursText, label: "Estudo total",
                     valueColor: goldMuted.opacity(0.90))
            statCard(icon: "checkmark.square.fill", value: accuracyText, label: "Acerto medio",
                     valueColor: greenStat.opacity(0.85))
            statCard(icon: "text.badge.checkmark", value: flashcardsText, label: "Respondidas",
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

    private func weeklyChart(vm: ProgressoViewModel) -> some View {
        let maxHour = vm.weeklyHours.max() ?? 1
        let normalizedBars = vm.weeklyHours.map { maxHour > 0 ? $0 / maxHour : 0 }
        let calendar = Calendar.current
        let rawWeekday = calendar.component(.weekday, from: Date())
        let todayIdx = (rawWeekday + 5) % 7

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Esta semana")

            glassCard {
                VStack(spacing: 12) {
                    HStack {
                        Text(String(format: "%.1f", vm.weeklyActualHours) + "h de \(Int(vm.weeklyGoalHours))h")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                        Spacer()
                        Text("Meta semanal")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        let labels = ["S", "T", "Q", "Q", "S", "S", "D"]
                        ForEach(0..<7, id: \.self) { idx in
                            barColumn(
                                label: labels[idx],
                                heightFraction: normalizedBars[idx],
                                isToday: idx == todayIdx
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

            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 2,
                bottomTrailingRadius: 2,
                topTrailingRadius: 6
            )
            .fill(
                isToday
                    ? LinearGradient(
                        colors: [VitaColors.accent.opacity(0.70), goldPrimary.opacity(0.50)],
                        startPoint: .bottom, endPoint: .top
                      )
                    : LinearGradient(
                        colors: [VitaColors.accent.opacity(0.35), VitaColors.accent.opacity(0.15)],
                        startPoint: .bottom, endPoint: .top
                      )
            )
            .frame(height: max(heightFraction * 76, heightFraction > 0 ? 4 : 0))
            .shadow(color: isToday ? VitaColors.accent.opacity(0.18) : .clear, radius: 6, y: -2)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isToday ? goldMuted.opacity(0.70) : VitaColors.textWarm.opacity(0.28))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weak Areas ("Onde melhorar")

    private func weakAreasSection(vm: ProgressoViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Onde melhorar")

            glassCard {
                VStack(spacing: 0) {
                    ForEach(Array(vm.subjects.sorted(by: { $0.accuracy < $1.accuracy }).prefix(5).enumerated()), id: \.offset) { idx, subject in
                        let pct = Int(subject.accuracy * 100)
                        let color = pct < 60
                            ? Color(red: 1.0, green: 0.471, blue: 0.314)
                            : Color(red: 1.0, green: 0.784, blue: 0.392)
                        let hoursText = subject.hoursSpent < 1
                            ? "\(Int(subject.hoursSpent * 60))min"
                            : String(format: "%.0fh", subject.hoursSpent)
                        weakAreaRow(
                            name: subject.subjectId,
                            meta: "\(subject.questionCount) questões · \(hoursText) estudo",
                            pct: pct,
                            color: color
                        )
                        if idx < min(vm.subjects.count, 5) - 1 {
                            dividerLine
                        }
                    }
                }
            }
        }
    }

    private func weakAreaRow(name: String, meta: String, pct: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            // Subject initial in circle instead of hardcoded image
            Text(String(name.prefix(2)).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(goldMuted.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(VitaColors.glassInnerLight.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text(meta)
                    .font(.system(size: 10))
                    .foregroundStyle(textSec)
            }

            Spacer()

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 48, height: 4)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.65), color.opacity(0.40)],
                            startPoint: .leading, endPoint: .trailing
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

    private func leaderboardSection(vm: ProgressoViewModel) -> some View {
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

                    if vm.leaderboard.isEmpty {
                        Text("Nenhum dado de ranking ainda")
                            .font(.system(size: 12))
                            .foregroundStyle(textSec)
                            .padding(.vertical, 20)
                    } else {
                        // Other users (not me)
                        let others = vm.leaderboard.filter { !$0.isMe }.prefix(5)
                        ForEach(Array(others.enumerated()), id: \.offset) { idx, entry in
                            lbRow(
                                rank: entry.rank,
                                initials: entry.initials,
                                name: entry.name,
                                xp: "\(entry.xp) XP",
                                rankColor: rankColorForPosition(entry.rank),
                                avatarBg: avatarColorForPosition(entry.rank),
                                isMe: false
                            )
                            if idx < others.count - 1 {
                                lbDivider
                            }
                        }

                        // My entry
                        if let me = vm.myLeaderboardEntry {
                            Rectangle()
                                .fill(goldPrimary.opacity(0.08))
                                .frame(height: 1)
                                .padding(.horizontal, 14)
                                .padding(.top, 6)

                            HStack {
                                Text("SUA POSICAO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(VitaColors.textWarm.opacity(0.25))
                                    .tracking(0.5)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 2)

                            lbRow(
                                rank: me.rank,
                                initials: me.initials,
                                name: me.name,
                                xp: "\(me.xp) XP",
                                rankColor: goldMuted.opacity(0.80),
                                avatarBg: goldPrimary,
                                isMe: true
                            )
                        }
                    }
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
                .font(.system(size: 13, weight: .bold))
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
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )

            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isMe ? goldMuted.opacity(0.90) : Color.white.opacity(0.85))

            Spacer()

            Text(xp)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(goldMuted.opacity(0.70))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isMe ? AnyShapeStyle(VitaColors.glassInnerLight.opacity(0.06)) : AnyShapeStyle(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var lbDivider: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.04))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - Heatmap

    private func heatmapSection(vm: ProgressoViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Últimos \(vm.heatmap.count) dias")

            glassCard {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 13)

                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<vm.heatmap.count, id: \.self) { i in
                        Rectangle()
                            .fill(heatmapColor(vm.heatmap[i]))
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
