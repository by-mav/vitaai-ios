import SwiftUI

// MARK: - Estudos Builder — components compartilhados (Fase 2 reescrita 3 paginas)
//
// SOT do spec: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md
//
// Cada page (Questoes/Simulados/Flashcards) compõe estes blocks no mesmo
// padrão visual. Diff é o conteúdo específico (qual seção colapsa, qual
// não tem cronômetro, qual tem mode selector). Layout geral compartilhado.

// MARK: - FilterChipsRow — tags removíveis dos filtros aplicados

/// Stack horizontal de chips removíveis ("🏷️ Cardio ✕ · ULBRA ✕ · 2024+ ✕").
/// Quando vazio, se esconde. Botão "Limpar" ao lado quando há ≥2 chips.
struct FilterChipsRow: View {
    struct Chip: Identifiable, Hashable {
        let id: String
        let label: String
        let onRemove: () -> Void

        static func == (a: Chip, b: Chip) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    let chips: [Chip]
    let theme: StudyShellTheme
    let onClearAll: (() -> Void)?

    var body: some View {
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if chips.count >= 2, let onClearAll {
                    HStack {
                        Text("Filtros (\(chips.count))")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(VitaColors.sectionLabel)
                        Spacer()
                        Button("Limpar") { onClearAll() }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.primaryLight.opacity(0.85))
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(chips) { chip in
                            chipPill(chip: chip)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func chipPill(chip: Chip) -> some View {
        Button(action: chip.onRemove) {
            HStack(spacing: 5) {
                Text(chip.label)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(theme.primaryLight.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(theme.primary.opacity(0.20))
            )
            .overlay(
                Capsule()
                    .stroke(theme.primaryLight.opacity(0.30), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GroupRow — uma linha de grupo (disciplina/sistema/great-area) com count

/// Linha selecionável estilo MedEvo: bullet color + nome + count à direita.
/// Tap toggla seleção; multi-select.
struct GroupRow: View {
    let slug: String
    let name: String
    let count: Int
    let isSelected: Bool
    let theme: StudyShellTheme
    let action: () -> Void

    private var formattedCount: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.5))
                Text(name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Text(formattedCount)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SpecialtyMultiSelect — busca + lista expandível com count

/// Card glass que mostra os top-N grupos visíveis + campo de busca quando
/// expandido + botão "Mais ↓" pra ver toda a lista. Filtro principal das
/// 3 telas; muda label conforme lente (Disciplinas/Sistemas/Áreas).
struct SpecialtyMultiSelect: View {
    let title: String
    let groups: [QBankFiltersGroupsInner]
    @Binding var selectedSlugs: Set<String>
    let theme: StudyShellTheme

    @State private var search: String = ""
    @State private var expanded: Bool = false

    private var filtered: [QBankFiltersGroupsInner] {
        guard !search.isEmpty else { return groups }
        let q = search.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return groups.filter {
            ($0.name ?? "")
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .contains(q)
        }
    }

    private var visible: [QBankFiltersGroupsInner] {
        if expanded || filtered.count <= 6 { return filtered }
        return Array(filtered.prefix(6))
    }

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                header
                if expanded { searchBar }
                Divider().background(VitaColors.glassBorder.opacity(0.4))
                rowsList
                if filtered.count > 6 { footerToggle }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            if !selectedSlugs.isEmpty {
                Text("· \(selectedSlugs.count) selec.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.primaryLight)
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                Image(systemName: expanded ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.primaryLight.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textTertiary)
            TextField("Buscar...", text: $search)
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VitaColors.surfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var rowsList: some View {
        VStack(spacing: 0) {
            if visible.isEmpty {
                Text(search.isEmpty ? "Nenhum resultado disponível" : "Nada encontrado para \"\(search)\"")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(visible, id: \.slug) { group in
                    let slug = group.slug ?? ""
                    let isSelected = selectedSlugs.contains(slug)
                    GroupRow(
                        slug: slug,
                        name: group.name ?? slug,
                        count: group.count ?? 0,
                        isSelected: isSelected,
                        theme: theme,
                        action: {
                            if isSelected { selectedSlugs.remove(slug) }
                            else { selectedSlugs.insert(slug) }
                        }
                    )
                    if group.slug != visible.last?.slug {
                        Divider()
                            .background(VitaColors.glassBorder.opacity(0.3))
                            .padding(.leading, 40)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footerToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
        } label: {
            HStack {
                Text(expanded ? "Mostrar menos" : "Ver todos (\(filtered.count))")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(theme.primaryLight.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FormatPills — chips de formato (Objetivas/Discursivas/c/Imagem)

struct FormatPills: View {
    @Binding var selected: Set<String>  // 'objective' | 'discursive' | 'withImage'
    let theme: StudyShellTheme

    private let options: [(slug: String, label: String, icon: String)] = [
        ("objective", "Objetivas", "list.bullet"),
        ("discursive", "Discursivas", "text.alignleft"),
        ("withImage", "Com Imagem", "photo"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FORMATO")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            HStack(spacing: 6) {
                ForEach(options, id: \.slug) { opt in
                    let isSelected = selected.contains(opt.slug)
                    Button {
                        if isSelected { selected.remove(opt.slug) }
                        else { selected.insert(opt.slug) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: opt.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(opt.label)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? theme.primaryLight.opacity(0.98) : VitaColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isSelected ? theme.primary.opacity(0.22) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(isSelected ? theme.primaryLight.opacity(0.32) : VitaColors.glassBorder, lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - AdvancedSection — collapsible group de toggles

struct AdvancedToggleItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String?
    let isOn: Bool
    let action: () -> Void
}

struct AdvancedSection: View {
    let items: [AdvancedToggleItem]
    let theme: StudyShellTheme

    @State private var expanded: Bool = false

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.primaryLight.opacity(0.9))
                        Text("AVANÇADAS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(VitaColors.sectionLabel)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    Divider().background(VitaColors.glassBorder.opacity(0.4))
                    VStack(spacing: 6) {
                        ForEach(items) { item in
                            QBankConfigToggleRow(
                                icon: item.icon,
                                title: item.title,
                                description: item.description ?? "",
                                isOn: item.isOn,
                                action: item.action
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - StickyBottomCTA — count vivo + botão "Iniciar"
//
// Usado via `.safeAreaInset(edge: .bottom)` no ScrollView. Isso garante:
// 1. Conteúdo do scroll respeita automaticamente a altura do CTA
//    (sem precisar de Spacer(minLength:) ou padding fake).
// 2. CTA fica grudado acima da custom tab bar (VitaTabBar mora em overlay
//    fora do safe area do sistema, então reservamos os ~94px manualmente
//    via `tabBarReserve` abaixo).
// 3. Background gradient se mistura naturalmente sobre o conteúdo do scroll
//    sem cobrir nem ser coberto pelo tab bar.
//
// Bug fix 2026-04-28: antes usava ZStack(alignment:.bottom) com padding
// .bottom 140 fixo, mas como AppRouter aplica `.ignoresSafeArea(.container,
// edges: .bottom)` no activeTabView, o CTA renderizava em coordenada fora
// da viewport útil. Rafael cobrou 5x, agora usa o pattern canônico SwiftUI.
struct StickyBottomCTA: View {
    let title: String
    let count: Int
    let isLoading: Bool
    let isCreating: Bool
    let theme: StudyShellTheme
    let action: () -> Void

    /// Altura visual do VitaTabBar custom (54) + safe area bottom típico
    /// iPhone moderno (~34) + folga visual (6) = 94. Tab bar mora em
    /// overlay no AppRouter, então não conta no safeAreaInset do sistema.
    private let tabBarReserve: CGFloat = 94

    private var formattedCount: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    var body: some View {
        VStack(spacing: 6) {
            if isCreating {
                HStack(spacing: 8) {
                    ProgressView().tint(theme.primaryLight)
                    Text("Montando sessão...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.primaryLight)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                StudyShellCTA(
                    title: title,
                    theme: theme,
                    action: action,
                    systemImage: "play.fill"
                )
                .opacity(count > 0 ? 1.0 : 0.4)
                .disabled(count == 0)
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, tabBarReserve)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: VitaColors.surface.opacity(0.92), location: 0.25),
                    .init(color: VitaColors.surface, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }
}

// MARK: - CollapsibleSectionCard — wrapper genérico pra seções colapsáveis
//
// Spec §11.2: as 5 seções secundárias (Instituições, Anos, Formato,
// Dificuldade, Avançadas) iniciam colapsadas. AdvancedSection já tem o
// padrão; este wrapper aplica o mesmo a Formato/Dificuldade sem reescrever.
struct CollapsibleSectionCard<Content: View>: View {
    let title: String
    let icon: String?
    let summary: String?       // ex: "Todos · 60", "Sem filtro"
    let theme: StudyShellTheme
    @Binding var expanded: Bool
    let content: () -> Content

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.primaryLight.opacity(0.9))
                        }
                        Text(title.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(VitaColors.sectionLabel)
                        if let summary, !expanded {
                            Text("· \(summary)")
                                .font(.system(size: 11))
                                .foregroundStyle(VitaColors.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    Divider().background(VitaColors.glassBorder.opacity(0.4))
                    content()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - InstitutionsCollapsibleSection — header colapsável que abre sheet
//
// Header colapsado mostra "🏥 Instituições · Todas (60) ›". Tap abre sheet
// full-screen com search + lista buscável + checkboxes. Selecionados aparecem
// como tags removíveis no FilterChipsRow (composição na screen).
struct InstitutionsCollapsibleSection: View {
    let institutions: [QBankInstitution]
    @Binding var selectedIds: Set<Int>
    let theme: StudyShellTheme

    @State private var sheetOpen: Bool = false

    private var summaryText: String {
        if selectedIds.isEmpty { return "Todas (\(institutions.count))" }
        return "\(selectedIds.count) selecionada\(selectedIds.count == 1 ? "" : "s")"
    }

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            Button {
                sheetOpen = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.primaryLight.opacity(0.9))
                    Text("INSTITUIÇÕES")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(VitaColors.sectionLabel)
                    Text("· \(summaryText)")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $sheetOpen) {
            InstitutionsPickerSheet(
                institutions: institutions,
                selectedIds: $selectedIds,
                theme: theme
            )
            .presentationDetents([.large])
            .presentationBackground(.ultraThinMaterial)
        }
    }
}

private struct InstitutionsPickerSheet: View {
    let institutions: [QBankInstitution]
    @Binding var selectedIds: Set<Int>
    let theme: StudyShellTheme

    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""

    private var filtered: [QBankInstitution] {
        guard !search.isEmpty else { return institutions }
        let q = search.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return institutions.filter {
            $0.name.folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
                .contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Instituições")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                if !selectedIds.isEmpty {
                    Button("Limpar") { selectedIds.removeAll() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.primaryLight)
                }
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(VitaColors.textTertiary)
                TextField("Buscar instituição...", text: $search)
                    .font(.system(size: 14))
                    .foregroundStyle(VitaColors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(VitaColors.surfaceElevated.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider().background(VitaColors.glassBorder.opacity(0.4))

            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    if filtered.isEmpty {
                        Text(search.isEmpty ? "Nenhuma instituição disponível" : "Nada encontrado para \"\(search)\"")
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(filtered) { inst in
                            row(for: inst)
                            if inst.id != filtered.last?.id {
                                Divider()
                                    .background(VitaColors.glassBorder.opacity(0.3))
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func row(for inst: QBankInstitution) -> some View {
        let isSelected = selectedIds.contains(inst.id)
        Button {
            if isSelected { selectedIds.remove(inst.id) }
            else { selectedIds.insert(inst.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.55))
                VStack(alignment: .leading, spacing: 2) {
                    Text(inst.name)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.92))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let state = inst.state, !state.isEmpty {
                        Text(state)
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
                Spacer()
                if let count = inst.count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - YearsRangeSection — presets + range slider
//
// Header colapsado: "📅 Anos · Todos · Tap pra filtrar ›". Expand inline com
// 3 presets [Todos] [Últimos 5] [Desde 2020] + range slider 1995-2026.
struct YearsRangeSection: View {
    @Binding var minYear: Int?
    @Binding var maxYear: Int?
    let availableMin: Int
    let availableMax: Int
    let theme: StudyShellTheme
    @Binding var expanded: Bool
    /// Callback unificado pra disparar refresh preview no VM (debounced lá).
    let onChange: () -> Void

    private var summaryText: String {
        switch (minYear, maxYear) {
        case (nil, nil): return "Todos"
        case (let lo?, let hi?): return "\(lo)–\(hi)"
        case (let lo?, nil):    return "Desde \(lo)"
        case (nil, let hi?):    return "Até \(hi)"
        default:                return "Todos"
        }
    }

    var body: some View {
        CollapsibleSectionCard(
            title: "Anos",
            icon: "calendar",
            summary: summaryText,
            theme: theme,
            expanded: $expanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Presets
                HStack(spacing: 6) {
                    presetChip(label: "Todos", isSelected: minYear == nil && maxYear == nil) {
                        minYear = nil; maxYear = nil; onChange()
                    }
                    presetChip(label: "Últimos 5", isSelected: isPresetLast5()) {
                        minYear = max(availableMin, availableMax - 4)
                        maxYear = availableMax
                        onChange()
                    }
                    presetChip(label: "Desde 2020", isSelected: minYear == 2020 && maxYear == nil) {
                        minYear = 2020
                        maxYear = nil
                        onChange()
                    }
                    Spacer(minLength: 0)
                }

                // Range info
                HStack {
                    Text("\(minYear ?? availableMin)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.primaryLight)
                    Spacer()
                    Text("\(maxYear ?? availableMax)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.primaryLight)
                }

                // Min/Max sliders (SwiftUI native; double-handle range slider not native iOS 16,
                // mantemos 2 sliders empilhados claros — sem AI slop de gesture custom).
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ano mínimo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(VitaColors.textTertiary)
                    Slider(
                        value: Binding(
                            get: { Double(minYear ?? availableMin) },
                            set: { newVal in
                                let v = Int(newVal.rounded())
                                minYear = v == availableMin ? nil : v
                                if let mx = maxYear, v > mx { maxYear = v }
                                onChange()
                            }
                        ),
                        in: Double(availableMin)...Double(availableMax),
                        step: 1
                    )
                    .tint(theme.primaryLight)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ano máximo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(VitaColors.textTertiary)
                    Slider(
                        value: Binding(
                            get: { Double(maxYear ?? availableMax) },
                            set: { newVal in
                                let v = Int(newVal.rounded())
                                maxYear = v == availableMax ? nil : v
                                if let mn = minYear, v < mn { minYear = v }
                                onChange()
                            }
                        ),
                        in: Double(availableMin)...Double(availableMax),
                        step: 1
                    )
                    .tint(theme.primaryLight)
                }
            }
        }
    }

    private func isPresetLast5() -> Bool {
        guard let lo = minYear, let hi = maxYear else { return false }
        return lo == max(availableMin, availableMax - 4) && hi == availableMax
    }

    @ViewBuilder
    private func presetChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.primary.opacity(0.22) : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? theme.primaryLight.opacity(0.32) : VitaColors.glassBorder, lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ModePills — variantes "modo" pra Simulado e Flashcard

/// Selector de "modo" tipo segmented control gold-glass. Usado em:
/// - Simulado: [Template · Custom]
/// - Flashcard: [Revisão · Específico · Novos]
struct ModePills<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String
    let icon: (T) -> String
    let theme: StudyShellTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODO")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            HStack(spacing: 6) {
                ForEach(options) { opt in
                    let isSelected = selection == opt
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = opt }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: icon(opt))
                                .font(.system(size: 14, weight: .semibold))
                            Text(label(opt))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? theme.primaryLight.opacity(0.98) : VitaColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(isSelected ? theme.primary.opacity(0.22) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(isSelected ? theme.primaryLight.opacity(0.32) : VitaColors.glassBorder, lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
