import SwiftUI

// MARK: - AtlasSearchSheet — busca enriquecida do Atlas 3D
//
// Empty state (antes de digitar):
//   • 4 chips: Cai muito / Continuar / Aleatório / Do dia
//   • Counter discreto "4.887 estruturas no catálogo"
//
// Filtros sistema (acima da search bar):
//   • Chip row scrollable: Todos / Ossos / Articulações / Músculos / Nervos /
//     Vasos / Linfáticos / Vísceras (mapeia 1:1 pros 7 layers)
//
// Resultados ricos (durante digitação):
//   • Ícone do sistema (SF Symbols) + nome PT em destaque + EN em cinza
//   • Chip lateralidade quando o nome carrega .l/.r ou prefixo Left/Right
//   • Chip frequência exam (high/medium/low) — gold quando high
//   • Highlight do termo digitado em dourado
//
// Voz: VitaVoiceInput nativo (Speech.framework) — botão à direita da search.
//
// History: persistido em UserDefaults (chave "atlas.history.v1") — últimos 10
// IDs visualizados, mais recente primeiro. Backend NOVA virá em rotas futuras
// (`POST /api/atlas/history`); enquanto isso a fonte é local.
//
// Daily: deterministic — hash da data do dia (yyyy-MM-dd) + count do lookup
// → mesma peça pra todos no mesmo dia.

// MARK: - History store

/// Persistência simples em UserDefaults dos últimos N IDs visualizados.
/// Usado pelo chip "Continuar" enquanto NOVA não publica `/atlas/history`.
enum AtlasHistoryStore {
    private static let key = "atlas.history.v1"
    private static let maxEntries = 10

    static func recordView(_ id: String) {
        guard !id.isEmpty else { return }
        var current = recent()
        current.removeAll { $0 == id }
        current.insert(id, at: 0)
        if current.count > maxEntries {
            current = Array(current.prefix(maxEntries))
        }
        UserDefaults.standard.set(current, forKey: key)
    }

    static func recent() -> [String] {
        UserDefaults.standard.array(forKey: key) as? [String] ?? []
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - System chip mapping

/// Mapeia raw system string → label PT-BR + SF Symbol pro chip de sistema.
/// `nil` raw = chip "Todos".
struct AtlasSystemChip: Identifiable, Hashable {
    let id: String          // raw system id ("arthrology") ou "all"
    let label: String       // PT-BR display
    let symbol: String      // SF Symbol
    let layerId: String?    // raw value pra matching com lookup.system

    static let all: AtlasSystemChip = .init(
        id: "all", label: "Todos", symbol: "circle.grid.3x3.fill", layerId: nil
    )

    static let ordered: [AtlasSystemChip] = [
        .all,
        .init(id: "arthrology",    label: "Ossos",        symbol: "figure.stand",                          layerId: "arthrology"),
        .init(id: "joints",        label: "Articulações", symbol: "circle.dashed",                         layerId: "joints"),
        .init(id: "myology",       label: "Músculos",     symbol: "figure.strengthtraining.functional",    layerId: "myology"),
        .init(id: "neurology",     label: "Nervos",       symbol: "brain",                                 layerId: "neurology"),
        .init(id: "angiology",     label: "Vasos",        symbol: "heart.fill",                            layerId: "angiology"),
        .init(id: "lymphoid",      label: "Linfático",    symbol: "drop.fill",                             layerId: "lymphoid"),
        .init(id: "splanchnology", label: "Vísceras",     symbol: "lungs.fill",                            layerId: "splanchnology"),
    ]

    /// Lookup helper: rawValue → SF Symbol (usado também pelos rows de result).
    static func symbol(for system: String) -> String {
        ordered.first { $0.layerId == system }?.symbol ?? "circle.dashed"
    }

    /// Lookup helper: rawValue → label PT-BR.
    static func label(for system: String) -> String {
        ordered.first { $0.layerId == system }?.label ?? system.capitalized
    }
}

// MARK: - Daily picker

/// Seleciona deterministicamente uma peça do lookup por data — todo mundo vê
/// a mesma "peça do dia" no mesmo dia. Hash YYYY-MM-DD → index.
enum AtlasDailyPicker {
    static func pickToday(from lookup: [String: MeshInfo]) -> MeshInfo? {
        guard !lookup.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: Date())
        let hash = abs(key.hashValue)
        // Dedup por id pra não cair sempre num .l/.r de uma mesma peça
        // (mesmo se o hash bateu numa chave, o pt+id são iguais).
        var seen = Set<String>()
        var unique: [MeshInfo] = []
        for k in lookup.keys.sorted() {
            guard let info = lookup[k] else { continue }
            let dedupKey = info.id.isEmpty ? k : info.id
            if seen.insert(dedupKey).inserted { unique.append(info) }
        }
        guard !unique.isEmpty else { return nil }
        let index = hash % unique.count
        return unique[index]
    }
}

// MARK: - AtlasSearchSheet

/// Sheet de busca enriquecida do Atlas 3D. Usada via `.sheet` no
/// `AtlasSceneScreen`. Emite `onPick(MeshInfo)` quando o usuário escolhe
/// uma peça (o caller fecha o sheet, entra em focus mode e abre o detail).
struct AtlasSearchSheet: View {
    let lookup: [String: MeshInfo]
    let activeLayerIds: Set<String>
    let onPick: (MeshInfo) -> Void

    @State private var query: String = ""
    @State private var systemFilter: AtlasSystemChip = .all
    @State private var emptyTab: EmptyTab? = nil
    @FocusState private var focused: Bool

    /// Dedup do catálogo por `id`. `lookup` é indexado por **chave** ("Femur.l",
    /// "Femur.r", "Femur.i") e cada chave aponta pro MESMO `id="femur"` /
    /// `pt="Fêmur"` — iterar `lookup.values` mostraria a mesma peça 2-4 vezes.
    /// Mantém 1 representante por `id` único, ordem determinística (chaves
    /// ordenadas alfabeticamente — `.i/.j/.l/.r` cai no mesmo grupo).
    /// O `lookup` original NÃO é mexido (hit-test 3D usa as chaves originais).
    private var dedupedCatalog: [MeshInfo] {
        var seen = Set<String>()
        var out: [MeshInfo] = []
        let sortedKeys = lookup.keys.sorted()
        for k in sortedKeys {
            guard let info = lookup[k] else { continue }
            // ID vazio (catálogo legado) → fallback pra chave
            let dedupKey = info.id.isEmpty ? k : info.id
            if seen.insert(dedupKey).inserted {
                out.append(info)
            }
        }
        return out
    }

    /// Tabs do empty state — quando uma é tapada, expande lista abaixo dos
    /// chips (não navega pra outra tela).
    enum EmptyTab: Hashable {
        case caiMuito
        case continuar
        case daily
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            systemFilterRow
                .padding(.top, 8)
                .padding(.bottom, 10)
            searchBar
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            if query.count < 2 {
                emptyStateContent
            } else if filtered.isEmpty {
                noResultsState
            } else {
                resultsList
            }
        }
        .onAppear { focused = false } // Empty state primeiro; usuário toca pra digitar
    }

    // MARK: System filter row

    private var systemFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AtlasSystemChip.ordered) { chip in
                    systemChipButton(chip: chip)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func systemChipButton(chip: AtlasSystemChip) -> some View {
        let active = systemFilter == chip
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.easeInOut(duration: 0.22)) {
                systemFilter = chip
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: chip.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(chip.label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(active ? VitaColors.accent : VitaColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(active
                    ? VitaColors.accent.opacity(0.18)
                    : Color.white.opacity(0.05))
            )
            .overlay(
                Capsule().stroke(active
                    ? VitaColors.accent.opacity(0.5)
                    : Color.white.opacity(0.06), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Search bar (com mic)

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                TextField("Buscar — fíbula, aorta, miocárdio…", text: $query)
                    .focused($focused)
                    .font(.system(size: 15))
                    .foregroundStyle(VitaColors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.6)
            )

            VitaVoiceInput(onTranscript: { text in
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { return }
                query = clean
            })
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyStateContent: some View {
        VStack(spacing: 14) {
            quickActionRow

            if let tab = emptyTab {
                Divider().opacity(0.3).padding(.horizontal, 16)
                expandedEmptyTabContent(tab: tab)
            } else {
                Spacer().frame(height: 24)
                Text("\(lookup.count) estruturas no catálogo")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary.opacity(0.7))
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private var quickActionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                quickActionChip(
                    title: "Cai muito",
                    symbol: "flame.fill",
                    isExpanded: emptyTab == .caiMuito,
                    onTap: { toggleTab(.caiMuito) }
                )
                quickActionChip(
                    title: "Continuar",
                    symbol: "clock.arrow.circlepath",
                    isExpanded: emptyTab == .continuar,
                    onTap: { toggleTab(.continuar) }
                )
                quickActionChip(
                    title: "Aleatório",
                    symbol: "die.face.5.fill",
                    isExpanded: false, // não expande — dispara direto
                    onTap: pickRandom
                )
                quickActionChip(
                    title: "Do dia",
                    symbol: "sparkles",
                    isExpanded: emptyTab == .daily,
                    onTap: { toggleTab(.daily) }
                )
            }
            .padding(.horizontal, 16)
        }
    }

    private func toggleTab(_ tab: EmptyTab) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.easeInOut(duration: 0.28)) {
            emptyTab = (emptyTab == tab) ? nil : tab
        }
    }

    private func quickActionChip(
        title: String,
        symbol: String,
        isExpanded: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isExpanded ? VitaColors.accent : VitaColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(isExpanded
                    ? VitaColors.accent.opacity(0.18)
                    : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(isExpanded
                    ? VitaColors.accent.opacity(0.5)
                    : VitaColors.glassBorder, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func expandedEmptyTabContent(tab: EmptyTab) -> some View {
        switch tab {
        case .caiMuito:
            highYieldList
        case .continuar:
            historyList
        case .daily:
            dailyCard
        }
    }

    // MARK: Cai muito (high-yield) list — agrupado por sistema

    private var highYieldList: some View {
        let highYield = dedupedCatalog
            .filter { $0.exam == "high" }
            .filter { systemFilter == .all || $0.system == systemFilter.layerId }
        let grouped = Dictionary(grouping: highYield, by: { $0.system })
        let orderedKeys = grouped.keys.sorted { a, b in
            let ai = AtlasSystemChip.ordered.firstIndex(where: { $0.layerId == a }) ?? 99
            let bi = AtlasSystemChip.ordered.firstIndex(where: { $0.layerId == b }) ?? 99
            return ai < bi
        }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if highYield.isEmpty {
                    inlineEmpty(message: "Nenhuma peça \"cai muito\" pra esse filtro.")
                }
                ForEach(orderedKeys, id: \.self) { key in
                    if let items = grouped[key] {
                        groupSection(systemId: key, items: items.sorted(by: { $0.pt < $1.pt }))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxHeight: .infinity)
    }

    private func groupSection(systemId: String, items: [MeshInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: AtlasSystemChip.symbol(for: systemId))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VitaColors.accent)
                Text(AtlasSystemChip.label(for: systemId).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VitaColors.textSecondary)
                    .kerning(0.5)
                Text("\(items.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            VStack(spacing: 6) {
                ForEach(items.prefix(8)) { info in
                    resultRow(info: info)
                }
            }
        }
    }

    // MARK: Continuar (history) list

    private var historyList: some View {
        let recentIds = AtlasHistoryStore.recent()
        // Resolve via dedupedCatalog pra evitar achar 2x a mesma peça quando
        // o id casa com várias chaves (.l/.r/.i/.j). Pega o primeiro match.
        let dedupedById = Dictionary(uniqueKeysWithValues:
            dedupedCatalog.map { ($0.id, $0) }
        )
        let recent = recentIds.compactMap { dedupedById[$0] }
        return Group {
            if recent.isEmpty {
                inlineEmpty(
                    message: "Você ainda não viu nenhuma peça. Toque numa estrutura ou busque por nome.",
                    symbol: "clock"
                )
                .padding(.horizontal, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(recent) { info in
                            resultRow(info: info)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Daily card

    @ViewBuilder
    private var dailyCard: some View {
        if let daily = AtlasDailyPicker.pickToday(from: lookup) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                    Text("PEÇA DO DIA")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VitaColors.textSecondary)
                        .kerning(0.5)
                }
                Button {
                    onPick(daily)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(VitaColors.accent.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: AtlasSystemChip.symbol(for: daily.system))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(VitaColors.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(daily.pt)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(VitaColors.textPrimary)
                            HStack(spacing: 6) {
                                Text(AtlasSystemChip.label(for: daily.system))
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textSecondary)
                                if daily.exam == "high" {
                                    examChip(level: "high")
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(VitaColors.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        } else {
            inlineEmpty(message: "Nenhuma peça disponível.").padding(.horizontal, 16)
        }
    }

    // MARK: Random pick (dispatch direto)

    private func pickRandom() {
        UISelectionFeedbackGenerator().selectionChanged()
        let pool = dedupedCatalog.filter { info in
            !info.system.isEmpty && activeLayerIds.contains(info.system)
        }
        let candidates = pool.isEmpty ? dedupedCatalog : pool
        guard let pick = candidates.randomElement() else { return }
        onPick(pick)
    }

    // MARK: - Filtered results (live search)

    private var filtered: [MeshInfo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        var matches: [(MeshInfo, Int)] = []
        for info in dedupedCatalog {
            // System filter
            if systemFilter != .all, info.system != systemFilter.layerId { continue }
            let pt = info.pt.lowercased()
            let en = info.en.lowercased()
            var score = 0
            if pt.hasPrefix(q) { score = 100 }
            else if pt.contains(q) { score = 60 }
            else if en.hasPrefix(q) { score = 40 }
            else if en.contains(q) { score = 20 }
            if score == 0 { continue }
            // Boost de layer ativo
            if activeLayerIds.contains(info.system) { score += 50 }
            // Boost exam=high
            if info.exam == "high" { score += 30 }
            matches.append((info, score))
        }
        return matches
            .sorted { $0.1 > $1.1 || ($0.1 == $1.1 && $0.0.pt < $1.0.pt) }
            .prefix(50)
            .map { $0.0 }
    }

    private var resultsList: some View {
        // Group by system when search yields results from >1 system
        let bySystem = Dictionary(grouping: filtered, by: { $0.system })
        let multipleSystems = bySystem.keys.count > 1
        let orderedKeys = bySystem.keys.sorted { a, b in
            let ai = AtlasSystemChip.ordered.firstIndex(where: { $0.layerId == a }) ?? 99
            let bi = AtlasSystemChip.ordered.firstIndex(where: { $0.layerId == b }) ?? 99
            return ai < bi
        }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if multipleSystems {
                    ForEach(orderedKeys, id: \.self) { key in
                        if let items = bySystem[key] {
                            groupSection(systemId: key, items: items)
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        ForEach(filtered) { info in
                            resultRow(info: info)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Result row (rich)

    private func resultRow(info: MeshInfo) -> some View {
        Button {
            onPick(info)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(VitaColors.accent.opacity(info.exam == "high" ? 0.20 : 0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: AtlasSystemChip.symbol(for: info.system))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VitaColors.accent.opacity(info.exam == "high" ? 1.0 : 0.7))
                }
                VStack(alignment: .leading, spacing: 3) {
                    highlightedText(info.pt, term: query)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        if info.en != info.pt && !info.en.isEmpty {
                            Text(info.en)
                                .font(.system(size: 11))
                                .foregroundStyle(VitaColors.textSecondary.opacity(0.75))
                                .lineLimit(1)
                        }
                        if let lat = lateralidade(from: info.pt) {
                            sideChip(label: lat)
                        }
                        examChip(level: info.exam)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
    }

    /// Highlight do termo digitado em dourado dentro do nome PT.
    private func highlightedText(_ text: String, term: String) -> Text {
        let q = term.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return Text(text) }
        let lower = text.lowercased()
        let lowerQ = q.lowercased()
        guard let range = lower.range(of: lowerQ) else { return Text(text) }
        let head = String(text[..<range.lowerBound])
        let mid  = String(text[range])
        let tail = String(text[range.upperBound...])
        return Text(head)
             + Text(mid).foregroundStyle(VitaColors.accent)
             + Text(tail)
    }

    /// Detecta lateralidade pelo nome PT (sufixo `(esquerda)/(direita)/...` ou
    /// padrões `.l/.r`). Volta `nil` quando não houver marcador.
    private func lateralidade(from pt: String) -> String? {
        let lower = pt.lowercased()
        if lower.contains("(esquerda)") { return "esquerda" }
        if lower.contains("(direita)") { return "direita" }
        if lower.contains("(superior)") { return "superior" }
        if lower.contains("(inferior)") { return "inferior" }
        if lower.contains("(medial)") { return "medial" }
        if lower.contains("(lateral)") { return "lateral" }
        if lower.contains("(anterior)") { return "anterior" }
        if lower.contains("(posterior)") { return "posterior" }
        return nil
    }

    private func sideChip(label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VitaColors.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.white.opacity(0.07))
            )
    }

    @ViewBuilder
    private func examChip(level: String) -> some View {
        switch level {
        case "high":
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("Cai muito")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(VitaColors.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(VitaColors.accent.opacity(0.18)))
        case "medium":
            Text("Cai")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(VitaColors.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.07)))
        default:
            EmptyView()
        }
    }

    // MARK: - States

    private var noResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 38))
                .foregroundStyle(VitaColors.textSecondary.opacity(0.5))
            Text("Nada corresponde a \"\(query)\"")
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if systemFilter != .all {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        systemFilter = .all
                    }
                } label: {
                    Text("Buscar em todos os sistemas")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(VitaColors.accent.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func inlineEmpty(message: String, symbol: String = "tray") -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(VitaColors.textSecondary.opacity(0.5))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
