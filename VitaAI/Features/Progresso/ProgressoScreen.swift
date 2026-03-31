import SwiftUI

// MARK: - ProgressoScreen (matches progresso-mobile-v1.html mockup)
// Data-driven: uses ProgressoViewModel backed by gamification + progress APIs.

struct ProgressoScreen: View {
    @Environment(\.appContainer) private var container

    // Gold palette → VitaColors
    private let goldPrimary = VitaColors.accentHover
    private let goldMuted   = VitaColors.accentLight
    private let textPrimary = VitaColors.textPrimary
    private let textSec     = VitaColors.textSecondary
    private let textDim     = VitaColors.textTertiary
    private let greenStat   = VitaColors.dataGreen
    private let redStat     = VitaColors.dataRed
    private let glassBg     = VitaColors.glassBg
    private let glassBorder = VitaColors.glassBorder

    @State private var vm: ProgressoViewModel?
    @State private var selectedLeaderboardTab = 0 // 0=Semanal, 1=Mensal, 2=Total

    var body: some View {
        Group {
            if let vm {
                if vm.isLoading {
                    loadingState
                } else if let error = vm.error {
                    errorState(error)
                } else {
                    contentView(vm)
                }
            } else {
                loadingState
            }
        }
        .task {
            if vm == nil {
                let viewModel = ProgressoViewModel(api: container.api)
                vm = viewModel
                await viewModel.load()
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(goldPrimary)
            Text("Carregando progresso...")
                .font(.system(size: 13))
                .foregroundStyle(textSec)
            Spacer()
        }
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(goldPrimary.opacity(0.6))

            Text("Erro ao carregar")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(textPrimary)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                if let vm {
                    Task { await vm.load() }
                }
            } label: {
                Text("Tentar novamente")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(goldPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule()
                            .stroke(goldPrimary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Content

    private func contentView(_ vm: ProgressoViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                heroCard(vm)
                statsGrid(vm)
                weeklyChart(vm)
                weakAreasSection(vm)
                leaderboardSection(vm)
                heatmapSection(vm)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .refreshable {
            await vm.load()
        }
    }

    // MARK: - Hero Card (XP ring + streak)

    private func heroCard(_ vm: ProgressoViewModel) -> some View {
        let progress = vm.userProgress
        let level = progress?.level ?? 1
        let currentLevelXp = progress?.currentLevelXp ?? 0
        let xpToNext = progress?.xpToNextLevel ?? 100
        let levelTotal = currentLevelXp + xpToNext
        let levelRatio = levelTotal > 0 ? Double(currentLevelXp) / Double(levelTotal) : 0
        let streak = progress?.currentStreak ?? vm.streakDays

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
                                    VitaColors.accentHover.opacity(0.90),
                                    VitaColors.glassInnerLight.opacity(0.70)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))

                    Text("\(level)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(goldMuted.opacity(0.95))
                        .tracking(-0.5)

                    // XP label below ring
                    Text("\(currentLevelXp) XP")
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

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.authManager.userName ?? "Estudante")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.3)

                    Text("\(currentLevelXp) / \(levelTotal) XP para nivel \(level + 1)")
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

                    // Streak row
                    streakRow(streak: streak)
                        .padding(.top, 10)
                }
            }
            .padding(18)
        }
    }

    private func streakRow(streak: Int) -> some View {
        let labels = ["S", "T", "Q", "Q", "S", "S", "D"]
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: Date())
        // Convert Sunday=1..Saturday=7 to Mon=0..Sun=6
        let todayIdx = (todayWeekday + 5) % 7

        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { idx in
                let isOn = idx < todayIdx && idx >= max(0, todayIdx - streak)
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
                                : Color.white.opacity(0.06)
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

    private func statsGrid(_ vm: ProgressoViewModel) -> some View {
        let streakStr = "\(vm.streakDays)"
        let hoursStr = vm.totalStudyHours >= 1 ? "\(Int(vm.totalStudyHours))h" : "\(Int(vm.totalStudyHours * 60))m"
        let accuracyStr = "\(Int(vm.avgAccuracy * 100))%"
        let questionsStr = "\(vm.totalQuestions)"

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            statCard(icon: "chart.bar.fill", value: streakStr, label: "Dias streak", color: goldMuted)
            statCard(icon: "clock.fill", value: hoursStr, label: "Estudo total", color: goldMuted)
            statCard(icon: "checkmark.square.fill", value: accuracyStr, label: "Acerto médio", color: greenStat)
            statCard(icon: "rectangle.stack.fill", value: questionsStr, label: "Flashcards", color: goldMuted)
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
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

                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(color.opacity(0.90))
                        .tracking(-0.3)
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(textSec)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Weekly Chart

    private func weeklyChart(_ vm: ProgressoViewModel) -> some View {
        let hours = vm.weeklyHours
        let maxHour = max(hours.max() ?? 1, 1)
        let actual = vm.weeklyActualHours
        let goal = vm.weeklyGoalHours
        let cal = Calendar.current
        let todayIdx = (cal.component(.weekday, from: Date()) + 5) % 7

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Esta semana")

            glassCard {
                VStack(spacing: 12) {
                    HStack {
                        Text(goal > 0
                             ? "\(String(format: "%.1f", actual))h de \(Int(goal))h"
                             : "\(String(format: "%.1f", actual))h")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                        Spacer()
                        if goal > 0 {
                            Text("Meta semanal")
                                .font(.system(size: 10))
                                .foregroundStyle(textSec)
                        }
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        let labels = ["S", "T", "Q", "Q", "S", "S", "D"]
                        ForEach(0..<7, id: \.self) { idx in
                            let h = idx < hours.count ? hours[idx] : 0
                            barColumn(label: labels[idx], height: h / maxHour, isToday: idx == todayIdx)
                        }
                    }
                    .frame(height: 90)
                }
                .padding(14)
            }
        }
    }

    private func barColumn(label: String, height: CGFloat, isToday: Bool) -> some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 6)
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
                .frame(height: max(height * 76, height > 0 ? 4 : 0))
                .shadow(color: isToday ? VitaColors.accent.opacity(0.18) : .clear, radius: 5)

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(
                    isToday
                        ? goldMuted.opacity(0.70)
                        : textDim
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weak Areas

    private func weakAreasSection(_ vm: ProgressoViewModel) -> some View {
        // Show bottom 3 subjects by accuracy (worst first)
        let weakSubjects = vm.subjects
            .sorted { $0.accuracy < $1.accuracy }
            .prefix(3)

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Onde melhorar")

            if weakSubjects.isEmpty {
                glassCard {
                    Text("Nenhum dado de desempenho ainda")
                        .font(.system(size: 12))
                        .foregroundStyle(textDim)
                        .padding(14)
                }
            } else {
                glassCard {
                    VStack(spacing: 0) {
                        ForEach(Array(weakSubjects.enumerated()), id: \.offset) { idx, subject in
                            let pct = Int(subject.accuracy * 100)
                            let color: Color = pct < 60 ? redStat : VitaColors.accentHover
                            let meta: String = {
                                let h = "\(Int(subject.hoursSpent))h estudo"
                                if subject.questionCount > 0 {
                                    return "\(subject.questionCount) questões · \(h)"
                                }
                                return h
                            }()
                            weakAreaRow(
                                image: iconForSubjectId(subject.subjectId),
                                name: displayName(for: subject.subjectId),
                                meta: meta,
                                pct: pct,
                                color: color
                            )
                            if idx < weakSubjects.count - 1 {
                                dividerLine
                            }
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

            // Mini bar
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

    private func leaderboardSection(_ vm: ProgressoViewModel) -> some View {
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
                        Text("Nenhum dado de ranking disponivel")
                            .font(.system(size: 12))
                            .foregroundStyle(textDim)
                            .padding(14)
                    } else {
                        // Top 5 entries
                        ForEach(Array(vm.leaderboard.prefix(5).enumerated()), id: \.offset) { idx, entry in
                            let rankColor = rankColorForPosition(entry.rank)
                            let avatarBg = avatarColorForPosition(entry.rank)
                            let initials = initialsFrom(entry.displayName)
                            lbRow(
                                rank: entry.rank,
                                initials: initials,
                                name: entry.displayName,
                                xp: formatXp(entry.xp),
                                rankColor: rankColor,
                                avatarBg: avatarBg,
                                isMe: entry.isMe
                            )
                            if idx < min(vm.leaderboard.count, 5) - 1 {
                                lbDivider
                            }
                        }

                        // "Sua posicao" section — show if user is outside top 5
                        if let me = vm.myLeaderboardEntry, me.rank > 5 {
                            // Gold separator
                            Rectangle()
                                .fill(goldPrimary.opacity(0.08))
                                .frame(height: 1)
                                .padding(.horizontal, 14)
                                .padding(.top, 6)

                            Text("Sua posicao")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.25))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal, 14)
                                .padding(.top, 2)

                            lbRow(
                                rank: me.rank,
                                initials: initialsFrom(me.displayName),
                                name: me.displayName,
                                xp: formatXp(me.xp),
                                rankColor: goldMuted.opacity(0.80),
                                avatarBg: goldPrimary,
                                isMe: true
                            )
                        }

                        // Ver ranking completo
                        NavigationLink(value: Route.leaderboard) {
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
                                : Color.white.opacity(0.06)
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
                ? RoundedRectangle(cornerRadius: 10)
                    .fill(VitaColors.glassInnerLight.opacity(0.06))
                : nil
        )
    }

    private var lbDivider: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.04))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - Heatmap

    private func heatmapSection(_ vm: ProgressoViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Últimos 91 dias")

            glassCard {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 13)
                let data: [Int] = vm.heatmap.isEmpty
                    ? Array(repeating: 0, count: 91)
                    : vm.heatmap

                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<data.count, id: \.self) { i in
                        Rectangle()
                            .fill(heatmapColor(data[i]))
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

    // MARK: - Helpers

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

    // MARK: - Data Formatting Helpers

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

    private func initialsFrom(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func formatXp(_ xp: Int) -> String {
        if xp >= 1000 {
            // Brazilian format: 1.234 XP
            let formatted = String(format: "%d", xp)
            var result = ""
            for (i, c) in formatted.reversed().enumerated() {
                if i > 0 && i % 3 == 0 { result = "." + result }
                result = String(c) + result
            }
            return "\(result) XP"
        }
        return "\(xp) XP"
    }

    /// Map subjectId to an asset image. Falls back to generic.
    private func iconForSubjectId(_ id: String) -> String {
        let lower = id.lowercased()
        if lower.contains("farmacologia") { return "disc-farmacologia" }
        if lower.contains("patologia") { return "disc-patologia-geral" }
        if lower.contains("histologia") { return "disc-histologia" }
        if lower.contains("anatomia") { return "disc-anatomia" }
        if lower.contains("bioquimica") { return "disc-bioquimica" }
        if lower.contains("fisiologia") { return "disc-fisiologia-1" }
        return "disc-interprofissional"
    }

    /// Format subjectId into a human-readable name.
    private func displayName(for subjectId: String) -> String {
        subjectId
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
