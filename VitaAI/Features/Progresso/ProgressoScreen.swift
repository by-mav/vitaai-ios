import SwiftUI

// MARK: - ProgressoScreen (aba Progresso = Estatisticas/Conquistas, decisao Rafael 2026-06-17) (connected to real API via ProgressoViewModel)

struct ProgressoScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(Router.self) private var router

    // Gold palette from VitaColors
    private let goldPrimary = VitaColors.accentHover
    private let goldMuted   = VitaColors.accentLight
    private let textPrimary = VitaColors.textPrimary
    private let textSec     = VitaColors.textSecondary
    private let textDim     = VitaColors.textTertiary
    private let greenStat   = VitaColors.dataGreen
    private let glassBg     = VitaColors.glassBg
    private let glassBorder = VitaColors.glassBorder

    @State private var selectedLeaderboardTab = 0
    /// 0 = Alunos (.user), 1 = Faculdades (.university). Backend ganhou
    /// scope=user|university 2026-04-25 — Rafael pediu ranking de unis.
    @State private var selectedLeaderboardScope = 0
    /// Áreas expandidas no "Onde melhorar" (accordion). Rafael 2026-07-16:
    /// mostra as 6 grandes áreas fechadas; toca → abre as disciplinas.
    @State private var expandedAreas: Set<String> = []

    var body: some View {
        let vm = container.progressoViewModel
        return Group {
            if vm.isLoading && vm.userProgress == nil {
                VitaHeartbeatLoader(orbSize: 88)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.error, vm.userProgress == nil {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 32))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                        .foregroundStyle(textDim)
                    Text(error)
                        .font(.system(size: 13))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                        .foregroundStyle(textSec)
                        .multilineTextAlignment(.center)
                    Button("Tentar novamente") {
                        Task { await vm.load() }
                    }
                    .font(.system(size: 13, weight: .semibold))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                    .foregroundStyle(goldMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content(vm: vm)
            }
        }
        .refreshable {
            await vm.load()
        }
        .task {
            await vm.loadIfNeeded()
            ScreenLoadContext.finish(for: "Progresso")
        }
        .trackScreen("Progresso")
    }

    // Redesign 2026-07-16 (Rafael): uma história — "quão longe você chegou e o
    // que conquistou". Cada dado UMA vez. Herói (nível+XP+streak) → Medalhas de
    // rank (o coração) → Desempenho → Ranking → Consistência. Cortados: statsGrid,
    // weeklyChart, desempenhoButton, achievements-emoji e activity (redundantes).
    private func content(vm: ProgressoViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                heroCard(vm: vm)
                medalhasSection(vm: vm)
                if !vm.areaPerformance.isEmpty {
                    areaPerformanceSection(vm: vm)
                }
                leaderboardSection(vm: vm)
                if !vm.heatmap.isEmpty {
                    heatmapSection(vm: vm)
                }
            }
            .padding(.horizontal, 16)
            // Sem padding-bottom: passa por trás da TabBar Liquid Glass.
        }
    }

    // MARK: - Medalhas de rank (o coração da tela)

    private func medalhasSection(vm: ProgressoViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Medalhas")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                RankMedalView(axis: RankAxes.questions, count: vm.totalQuestions)
                RankMedalView(axis: RankAxes.streak, count: vm.streakDays)
                RankMedalView(axis: RankAxes.simulados, count: badgeCount(vm, prefix: "simulados"))
                RankMedalView(axis: RankAxes.flashcards, count: badgeCount(vm, prefix: "cards"))
            }
        }
    }

    /// Fase 1: sem contador exato por eixo, derivamos o piso do maior badge
    /// desbloqueado da categoria (id "simulados_25" → 25). Fase 2 = contador real
    /// do backend. 0 = medalha bloqueada.
    private func badgeCount(_ vm: ProgressoViewModel, prefix: String) -> Int {
        vm.badges
            .filter { $0.unlocked && $0.id.hasPrefix(prefix + "_") }
            .compactMap { Int($0.id.split(separator: "_").last ?? "") }
            .max() ?? 0
    }

    // MARK: - Onde melhorar (accordion por ÁREA → disciplinas)
    //
    // Rafael 2026-07-16: as 6 grandes áreas FECHADAS; toca uma → expande as
    // disciplinas dela. Mesma linguagem visual das medalhas (surfaceElevated +
    // relevo), sem o glassCard herdado que cortava o texto na borda.

    /// As 6 grandes áreas de PROVA (exam_great_areas, CNRM/ENARE) — a mesma
    /// taxonomia que flashcards/qbank/simulados usam (granularidade = disciplina).
    /// O dado vem de vm.areaPerformance (só as com questões); as demais aparecem
    /// "sem questões ainda". Rafael 2026-07-16.
    private static let allAreas: [(slug: String, name: String)] = [
        ("clinica-medica", "Clínica Médica"),
        ("cirurgia-geral", "Cirurgia Geral"),
        ("ginecologia-obstetricia", "Ginecologia e Obstetrícia"),
        ("pediatria", "Pediatria"),
        ("medicina-preventiva-social", "Medicina Preventiva e Social"),
        ("ciclo-basico", "Ciclo Básico"),
    ]

    private func areaPerformanceSection(vm: ProgressoViewModel) -> some View {
        // Ordena: áreas com questões primeiro (mais fracas no topo), resto depois.
        let bySlug = Dictionary(uniqueKeysWithValues: vm.areaPerformance.map { ($0.area, $0) })
        let rows = Self.allAreas.sorted { a, b in
            let da = bySlug[a.slug], db = bySlug[b.slug]
            if (da == nil) != (db == nil) { return da != nil }        // com dado antes
            if let da, let db { return da.accuracy < db.accuracy }     // mais fraca antes
            return false
        }
        // UM card grande, lista contínua (estilo Baralhos/flashcards) — Rafael.
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Onde melhorar")
            glassCard {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.slug) { idx, meta in
                        if idx > 0 { dividerLine }
                        areaRow(meta: meta, data: bySlug[meta.slug])
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
        }
    }

    private func areaRow(meta: (slug: String, name: String), data: QBankProgressByArea?) -> some View {
        let expanded = expandedAreas.contains(meta.slug)
        let hasData = (data?.disciplines.isEmpty == false)
        return VStack(spacing: 0) {
            Button {
                guard hasData else { return }
                HapticManager.shared.fire(.light)
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    if expanded { expandedAreas.remove(meta.slug) } else { expandedAreas.insert(meta.slug) }
                }
            } label: {
                HStack(spacing: 12) {
                    DisciplineIconBadge(name: meta.name, size: 44)
                        .opacity(hasData ? 1 : 0.4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meta.name)
                            .font(VitaTypography.titleMedium)
                            .foregroundStyle(hasData ? VitaColors.textPrimary : VitaColors.textSecondary)
                            .lineLimit(1)
                        Text(hasData
                            ? "\(data?.answered ?? 0) \(data?.answered == 1 ? "questão" : "questões") · \(data?.disciplines.count ?? 0) \(data?.disciplines.count == 1 ? "disciplina" : "disciplinas")"
                            : "Sem questões ainda")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    Spacer(minLength: 8)
                    if hasData, let data {
                        Text("\(data.accuracy)%")
                            .font(VitaTypography.titleMedium)
                            .foregroundStyle(accuracyColor(data.accuracy))
                            .monospacedDigit()
                        Image(systemName: "chevron.right")
                            .font(VitaTypography.titleSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded, let data {
                VStack(spacing: 0) {
                    ForEach(data.disciplines) { disc in
                        disciplineRow(disc)
                    }
                }
                .padding(.leading, 12)
                .padding(.bottom, 6)
            }
        }
    }

    private func disciplineRow(_ disc: QBankProgressByDiscipline) -> some View {
        HStack(spacing: 12) {
            DisciplineIconBadge(name: disc.name, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(disc.name)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary.opacity(0.92))
                    .lineLimit(1)
                Text("\(disc.answered) \(disc.answered == 1 ? "questão" : "questões")")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            Spacer(minLength: 10)
            Capsule().fill(VitaColors.glassInnerLight.opacity(0.10)).frame(width: 54, height: 6)
                .overlay(alignment: .leading) {
                    Capsule().fill(accuracyColor(disc.accuracy))
                        .frame(width: 54 * CGFloat(disc.accuracy) / 100.0, height: 6)
                }
            Text("\(disc.accuracy)%")
                .font(VitaTypography.labelLarge)
                .foregroundStyle(accuracyColor(disc.accuracy))
                .monospacedDigit()
                .frame(minWidth: 36, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }

    private func accuracyColor(_ pct: Int) -> Color {
        if pct >= 75 { return VitaColors.success }
        if pct >= 50 { return VitaColors.warning }
        return VitaColors.danger
    }

    // MARK: - Hero Card (unified with Dashboard/Faculdade style)

    private func heroCard(vm: ProgressoViewModel) -> some View {
        let level = vm.userProgress?.level ?? 1
        let currentXp = vm.userProgress?.currentLevelXp ?? vm.userProgress?.totalXp ?? 0
        let xpToNext = vm.userProgress?.xpToNextLevel ?? 100
        let totalXp = vm.userProgress?.totalXp ?? 0
        let missing = max(xpToNext - currentXp, 0)
        let levelRatio = xpToNext > 0 ? Double(currentXp) / Double(xpToNext) : 0

        let title = missing > 0
            ? "Faltam \(missing) XP pra Nível \(level + 1)"
            : "Pronto pra Nível \(level + 1)"

        // Enxuto (Rafael 2026-07-16): o herói guarda só XP total + streak. O resto
        // (respondidas, acerto) virou medalha/desempenho — cada dado uma vez.
        var stats: [(text: String, icon: String?)] = [
            ("\(totalXp) XP total", nil)
        ]
        if vm.streakDays > 0 {
            stats.append(("\(vm.streakDays) \(vm.streakDays == 1 ? "dia" : "dias") seguidos", "flame.fill"))
        }

        return VitaHeroCard(
            label: "NÍVEL \(level)",
            title: title,
            subtitle: "\(currentXp) de \(xpToNext) XP",
            progress: levelRatio,
            stats: stats,
            cta: "Ver ranking",
            bgImage: "hero-dashboard-v2",
            action: { /* scroll to leaderboard — no-op for now */ }
        )
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
                    // Scope segmented (Alunos / Faculdades) — Rafael pediu ranking
                    // de unis 2026-04-25. Visual: 2 tabs grandes no topo do card.
                    scopeSegmented
                        .padding(.horizontal, 14)
                        .padding(.top, 12)

                    // Period chips (Semanal / Mensal / Tudo)
                    HStack(spacing: 4) {
                        lbTab("Semanal", index: 0)
                        lbTab("Mensal", index: 1)
                        lbTab("Tudo", index: 2)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                    if vm.leaderboard.isEmpty {
                        Text(emptyMessageForCurrentLeaderboard)
                            .font(.system(size: 12))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                            .foregroundStyle(textSec)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 14)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    } else {
                        // Other entries (não eu / não minha faculdade)
                        let others = vm.leaderboard.filter { !$0.isMe }.prefix(5)
                        ForEach(Array(others.enumerated()), id: \.offset) { idx, entry in
                            lbRow(
                                rank: entry.rank,
                                initials: entry.initials,
                                name: entry.name,
                                subtitle: subtitleFor(entry),
                                xp: "\(formatXp(entry.xp)) XP",
                                rankColor: rankColorForPosition(entry.rank),
                                avatarBg: avatarColorForPosition(entry.rank),
                                isMe: false
                            )
                            if idx < others.count - 1 {
                                lbDivider
                            }
                        }

                        // My entry (ou minha faculdade)
                        if let me = vm.myLeaderboardEntry {
                            Rectangle()
                                .fill(goldPrimary.opacity(0.08))
                                .frame(height: 1)
                                .padding(.horizontal, 14)
                                .padding(.top, 6)

                            HStack {
                                Text(myPositionLabel)
                                    .font(.system(size: 10, weight: .bold))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
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
                                subtitle: subtitleFor(me),
                                xp: "\(formatXp(me.xp)) XP",
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

    // MARK: - Scope segmented (Alunos / Faculdades)

    private var scopeSegmented: some View {
        HStack(spacing: 0) {
            scopeChip("Alunos", index: 0, icon: "person")
            scopeChip("Faculdades", index: 1, icon: "graduationcap")
        }
        .frame(maxWidth: .infinity)
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12)  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                .fill(VitaColors.glassInnerLight.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                        .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func scopeChip(_ text: String, index: Int, icon: String) -> some View {
        Button {
            guard selectedLeaderboardScope != index else { return }
            selectedLeaderboardScope = index
            HapticManager.shared.fire(.light)
            let scope: LeaderboardScope = index == 0 ? .user : .university
            Task { await container.progressoViewModel.loadLeaderboard(scope: scope) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                Text(text)
                    .font(.system(size: 12, weight: .semibold))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
            }
            .foregroundStyle(
                selectedLeaderboardScope == index
                    ? goldMuted.opacity(0.95)
                    : VitaColors.textWarm.opacity(0.45)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 9)  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                    .fill(
                        selectedLeaderboardScope == index
                            ? VitaColors.accent.opacity(0.18)
                            : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers para scope-aware rendering

    private var emptyMessageForCurrentLeaderboard: String {
        selectedLeaderboardScope == 0
            ? "Sem alunos no ranking ainda. Estuda hoje pra aparecer aqui."
            : "Sem faculdades suficientes ainda. Convida tua turma!"
    }

    private var myPositionLabel: String {
        selectedLeaderboardScope == 0 ? "SUA POSIÇÃO" : "SUA FACULDADE"
    }

    private func subtitleFor(_ entry: LeaderboardEntry) -> String? {
        switch entry.scope {
        case .user:
            return entry.streak > 0 ? "\(entry.streak) dias 🔥" : nil
        case .university:
            let count = entry.studentCount.map { "\($0) alunos" } ?? ""
            let loc = [entry.city, entry.state].compactMap { $0 }.joined(separator: "/")
            return [count, loc].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    private func formatXp(_ xp: Int) -> String {
        if xp >= 1_000_000 { return String(format: "%.1fM", Double(xp) / 1_000_000) }
        if xp >= 10_000 { return String(format: "%.1fk", Double(xp) / 1000).replacingOccurrences(of: ".0k", with: "k") }
        return "\(xp)"
    }

    private func lbTab(_ text: String, index: Int) -> some View {
        Button {
            guard selectedLeaderboardTab != index else { return }
            selectedLeaderboardTab = index
            HapticManager.shared.fire(.light)
            let period = ["weekly", "monthly", "all"][index]
            Task { await container.progressoViewModel.loadLeaderboard(period: period) }
        } label: {
            Text(text)
                .font(.system(size: 10, weight: .bold))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
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

    private func lbRow(rank: Int, initials: String, name: String, subtitle: String? = nil, xp: String, rankColor: Color, avatarBg: Color, isMe: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .bold))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                .foregroundStyle(rankColor)
                .frame(width: 22)

            Text(initials)
                .font(.system(size: 10, weight: .bold))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
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

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                    .foregroundStyle(isMe ? goldMuted.opacity(0.90) : Color.white.opacity(0.85))
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                        .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(xp)
                .font(.system(size: 11, weight: .bold))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
                .foregroundStyle(goldMuted.opacity(0.70))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isMe ? AnyShapeStyle(VitaColors.glassInnerLight.opacity(0.06)) : AnyShapeStyle(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 10))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
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
                let activeDays = vm.heatmap.filter { $0 > 0 }.count

                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0..<vm.heatmap.count, id: \.self) { i in
                            Rectangle()
                                .fill(heatmapColor(vm.heatmap[i]))
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 3)) // ds-allow: célula ~8pt do heatmap, menor raio da escala (sm=8) já seria círculo
                        }
                    }
                    // Mapa quase vazio lia como "quebrado" — explicar a mecânica
                    // convida em vez de assustar (design review 2026-07-02).
                    if activeDays < 7 {
                        Text("Cada dia de estudo pinta um quadradinho de ouro. Seu mapa está só começando.")
                            .font(PixioTypo.caption)
                            .foregroundStyle(textSec)
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
            .font(.system(size: 10, weight: .semibold))  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
            .foregroundStyle(VitaColors.sectionLabel)
            .textCase(.uppercase)
            .kerning(0.8)
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VitaGlassCard(cornerRadius: 16) { content() }  // ds-allow: tela de stats — token debt herdado (tokenizar no gold do Progresso #33)
    }

    private func rankColorForPosition(_ rank: Int) -> Color {
        switch rank {
        case 1: return goldMuted.opacity(0.90)
        case 2: return VitaColors.medalSilver.opacity(0.70)
        case 3: return VitaColors.medalBronze.opacity(0.65)
        default: return textDim
        }
    }

    private func avatarColorForPosition(_ rank: Int) -> Color {
        switch rank {
        case 1: return goldPrimary
        case 2: return VitaColors.medalSilver
        case 3: return VitaColors.medalBronze
        default: return Color.white
        }
    }
}
