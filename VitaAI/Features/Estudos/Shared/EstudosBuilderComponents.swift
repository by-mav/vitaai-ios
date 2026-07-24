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
    var counts: [String: Int] = [:]

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
                    let count = counts[opt.slug]
                    Button {
                        if isSelected { selected.remove(opt.slug) }
                        else { selected.insert(opt.slug) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: opt.icon)
                                .font(.system(size: 11, weight: .semibold))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(opt.label)
                                    .font(VitaTypography.labelMedium.weight(.semibold))
                                if let count {
                                    Text(count.formatted(.number.locale(Locale(identifier: "pt_BR"))))
                                        .font(VitaTypography.labelSmall)
                                        .foregroundStyle(VitaColors.textTertiary)
                                }
                            }
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
                    .disabled(!isSelected && count == 0)
                    .opacity(!isSelected && count == 0 ? 0.38 : 1)
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
    private let tabBarReserve: CGFloat = 78

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

// MARK: - StudyAmountSliderCard — compact quantity picker

struct StudyAmountSliderCard: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let step: Int
    let theme: StudyShellTheme
    var valueSuffix: String = ""
    var presets: [Int] = []
    let onChange: (Int) -> Void

    @State private var expanded = false
    @State private var lastHapticValue: Int?

    private var clampedValue: Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private var displayValue: String {
        let suffix = valueSuffix.isEmpty ? "" : " \(valueSuffix)"
        return "\(formatNumber(clampedValue))\(suffix)"
    }

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    PixioHaptics.tap()
                    withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(theme.primary.opacity(0.16))
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.primaryLight.opacity(0.92))
                        }
                        .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(title)
                                .font(PixioTypo.caption)
                                .foregroundStyle(VitaColors.textPrimary.opacity(0.88))
                        }

                        Spacer()

                        Text(displayValue)
                            .font(PixioTypo.sans(size: 16, weight: .semibold))
                            .foregroundStyle(theme.primaryLight.opacity(0.95))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

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
                    Divider().background(VitaColors.glassBorder.opacity(0.35))
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(formatNumber(range.lowerBound))
                                .font(PixioTypo.micro)
                                .foregroundStyle(VitaColors.textTertiary)
                            Spacer()
                            Text(formatNumber(range.upperBound))
                                .font(PixioTypo.micro)
                                .foregroundStyle(VitaColors.textTertiary)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(clampedValue) },
                                set: { updateSliderValue($0) }
                            ),
                            in: Double(range.lowerBound)...Double(range.upperBound),
                            step: Double(max(1, step))
                        )
                        .tint(theme.primaryLight)

                        if !presets.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(presets, id: \.self) { preset in
                                    let safePreset = min(max(preset, range.lowerBound), range.upperBound)
                                    Button {
                                        PixioHaptics.soft()
                                        onChange(safePreset)
                                    } label: {
                                        Text(formatNumber(safePreset))
                                            .font(PixioTypo.micro)
                                            .foregroundStyle(clampedValue == safePreset ? theme.primaryLight : VitaColors.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 7)
                                            .background(
                                                Capsule()
                                                    .fill(clampedValue == safePreset ? theme.primary.opacity(0.18) : Color.clear)
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(clampedValue == safePreset ? theme.primaryLight.opacity(0.30) : VitaColors.glassBorder.opacity(0.7), lineWidth: 0.75)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onAppear { lastHapticValue = clampedValue }
    }

    private func updateSliderValue(_ rawValue: Double) {
        let stepped = quantizedValue(rawValue)
        guard stepped != clampedValue else { return }
        if lastHapticValue != stepped {
            PixioHaptics.soft()
            lastHapticValue = stepped
        }
        onChange(stepped)
    }

    private func quantizedValue(_ rawValue: Double) -> Int {
        let safeStep = max(1, step)
        let rounded = Int((rawValue / Double(safeStep)).rounded()) * safeStep
        return min(max(rounded, range.lowerBound), range.upperBound)
    }

    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

struct StudySliderOption: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?

    init(id: String, title: String, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
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
            .studyFilterSheet()
        }
    }
}

// MARK: - Apresentação canônica de sheet de filtro
//
// 🚨 Toda folha de filtro para ABAIXO do hero (Rafael 2026-07-20): "quero ver
// o número do hero mudando conforme o usuário escolhe". Com `.large` a folha
// cobria a tela inteira e o aluno escolhia às cegas — só descobria quantas
// questões sobraram depois de fechar. Deixando o hero à vista, cada toque na
// lista mostra o número correndo no odômetro; a escolha vira conversa.
//
// Fração, não altura fixa: a proporção se adapta do iPhone SE ao Pro Max, e
// altura fixa em conteúdo variável foi exatamente o bug do hero mais cedo hoje.
extension View {
    func studyFilterSheet() -> some View {
        self
            .presentationDetents([.fraction(StudyFilterSheetLayout.detent)])
            // 🚨 Material do CARD, não `.ultraThinMaterial` (Rafael 2026-07-20:
            // "não aquela merda cinza"). O material do sistema desbota pro
            // cinza e destoa da página inteira, que é grafite quente com fio
            // de ouro. A folha é continuação da página, não uma janela de
            // outro app.
            .presentationBackground { StudySheetSurface() }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(VitaTokens.Radius.xl)
    }
}

enum StudyFilterSheetLayout {
    /// O que sobra da tela depois do cabeçalho + hero. Medido no iPhone 17 Pro
    /// (874pt de altura, hero terminando por volta de 280pt).
    static let detent: CGFloat = 0.66
}

/// Fundo canônico das folhas de estudo: a MESMA base grafite do `VitaGlassCard`,
/// pra a folha e os cards da página parecerem o mesmo material sob a mesma luz.
struct StudySheetSurface: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 18 / 255, green: 19 / 255, blue: 23 / 255),  // ds-allow: gradiente/glow de fundo proprio (arte)
                    Color(red: 9 / 255, green: 10 / 255, blue: 13 / 255),  // ds-allow: gradiente/glow de fundo proprio (arte)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Brilho quente no topo: a luz entra por cima, como nos cards.
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 200 / 255, blue: 120 / 255).opacity(0.055),  // ds-allow: gradiente/glow de fundo proprio (arte)
                    .clear,
                ],
                center: .top,
                startRadius: 8,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
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
                    .font(PixioTypo.cardTitle)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                if !selectedIds.isEmpty {
                    Button("Limpar") { selectedIds.removeAll() }
                        .font(PixioTypo.caption)
                        .foregroundStyle(theme.primaryLight)
                }
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))  // ds-allow: botão fechar
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.top, VitaTokens.Spacing.lg)
            .padding(.bottom, VitaTokens.Spacing.md)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(PixioTypo.caption)
                    .foregroundStyle(VitaColors.textTertiary)
                TextField("Buscar instituição...", text: $search)
                    .font(PixioTypo.body)
                    .foregroundStyle(VitaColors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(PixioTypo.caption)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.md)
            .padding(.vertical, VitaTokens.Spacing.md)
            .background(VitaColors.surfaceElevated.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.md))
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.bottom, VitaTokens.Spacing.sm)

            Divider().background(VitaColors.glassBorder.opacity(0.4))

            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    if filtered.isEmpty {
                        Text(search.isEmpty ? "Nenhuma instituição disponível" : "Nada encontrado para \"\(search)\"")
                            .font(PixioTypo.caption)
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
                    .font(.system(size: 18))  // ds-allow: caixa de seleção
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.55))
                VStack(alignment: .leading, spacing: 2) {
                    Text(inst.name)
                        .font(PixioTypo.sans(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.92))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let state = inst.state, !state.isEmpty {
                        Text(state)
                            .font(PixioTypo.micro)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
                Spacer()
                if let count = inst.count, count > 0 {
                    Text("\(count)")
                        .font(PixioTypo.caption)
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.md)
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
    var counts: [String: Int] = [:]

    private var summaryText: String {
        switch (minYear, maxYear) {
        case (nil, nil): return "Todos"
        case (let lo?, let hi?): return "\(lo)–\(hi)"
        case (let lo?, nil):    return "Desde \(lo)"
        case (nil, let hi?):    return "Até \(hi)"
        default:                return "Todos"
        }
    }

    private var contextualSummary: String {
        guard !counts.isEmpty else { return summaryText }
        let lower = minYear ?? availableMin
        let upper = maxYear ?? availableMax
        let count = counts.reduce(into: 0) { total, entry in
            guard let year = Int(entry.key), year >= lower, year <= upper else { return }
            total += entry.value
        }
        return "\(summaryText) · \(count.formatted(.number.locale(Locale(identifier: "pt_BR"))))"
    }

    var body: some View {
        CollapsibleSectionCard(
            title: "Anos",
            icon: "calendar",
            summary: contextualSummary,
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

                // 1 barra de range com 2 alças (Rafael 2026-07-19: "nao faz sentido
                // ter duas barras, da pra fazer aquilo com 1 barra soh").
                YearRangeBar(
                    minYear: $minYear,
                    maxYear: $maxYear,
                    availableMin: availableMin,
                    availableMax: availableMax,
                    theme: theme,
                    onChange: onChange
                )
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

// MARK: - YearRangeBar — 1 barra de range com 2 alças (min/max numa track só)

/// Range slider de duas alças numa única track. Substitui os 2 sliders empilhados
/// (Rafael 2026-07-19). iOS 16+ não traz double-handle nativo — este é sob medida,
/// contido (track + range ativo + 2 thumbs), sem gesture exótica.
struct YearRangeBar: View {
    @Binding var minYear: Int?
    @Binding var maxYear: Int?
    let availableMin: Int
    let availableMax: Int
    let theme: StudyShellTheme
    let onChange: () -> Void

    private let trackHeight: CGFloat = 4
    private let thumb: CGFloat = 26

    private var lo: Int { minYear ?? availableMin }
    private var hi: Int { maxYear ?? availableMax }
    private var span: CGFloat { CGFloat(max(1, availableMax - availableMin)) }

    var body: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.width - thumb)
            let loX = CGFloat(lo - availableMin) / span * usable
            let hiX = CGFloat(hi - availableMin) / span * usable

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(VitaColors.glassBorder)
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumb / 2)
                Capsule()
                    .fill(theme.primaryLight)
                    .frame(width: max(0, hiX - loX), height: trackHeight)
                    .offset(x: loX + thumb / 2)
                handle
                    .offset(x: loX)
                    .gesture(dragGesture(usable: usable, isMin: true))
                handle
                    .offset(x: hiX)
                    .gesture(dragGesture(usable: usable, isMin: false))
            }
            .frame(height: thumb)
        }
        .frame(height: thumb)
    }

    private var handle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: thumb, height: thumb)
            .overlay(Circle().stroke(theme.primaryLight, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }

    private func dragGesture(usable: CGFloat, isMin: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let frac = min(max(0, (value.location.x - thumb / 2) / usable), 1)
                let year = availableMin + Int((frac * span).rounded())
                if isMin {
                    let clamped = min(year, hi)
                    minYear = clamped == availableMin ? nil : clamped
                } else {
                    let clamped = max(year, lo)
                    maxYear = clamped == availableMax ? nil : clamped
                }
                onChange()
            }
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

// MARK: - Linha de filtro que abre uma folha
//
// Mesma silhueta da InstitutionsCollapsibleSection (ícone · RÓTULO · resumo ·
// chevron), mas genérica: serve pra qualquer filtro cujo conteúdo mora numa
// folha separada em vez de expandir no lugar. Nasceu pra ESPECIALIDADES, que
// vivia escondida num card "Conteúdo" no fim da página em vez de estar entre
// os filtros (Rafael 2026-07-20).
struct QBankFilterRow: View {
    let icon: String
    let title: String
    let summary: String
    let theme: StudyShellTheme
    let action: () -> Void

    var body: some View {
        VitaGlassCard(cornerRadius: 14) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))  // ds-allow: ícone da linha de filtro
                        .foregroundStyle(theme.primaryLight.opacity(0.9))
                    Text(title)
                        .font(.system(size: 11, weight: .bold))  // ds-allow: rótulo da linha de filtro
                        .tracking(0.8)
                        .foregroundStyle(VitaColors.sectionLabel)
                    Text("· \(summary)")
                        .font(.system(size: 11))  // ds-allow: resumo da linha de filtro
                        .foregroundStyle(VitaColors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))  // ds-allow: chevron
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - YearsPickerSection — anos como LISTA, não como barra
//
// Substitui a barra de faixa (mín–máx) por marcação avulsa (Rafael 2026-07-20):
// ano à esquerda, quantas questões daquele ano à direita, toque pra marcar.
//
// A barra era errada por dois motivos. Primeiro, ela obrigava a pedir um
// intervalo contínuo: quem quisesse 2015, 2019 e 2024 levava junto os cinco
// anos do meio. Segundo, ela escondia o dado que decide a escolha — o aluno
// arrastava sem saber que 2011 tem 12 questões e 2023 tem 1.400.
//
// Mesma silhueta de INSTITUIÇÕES de propósito: os dois são "escolha itens de
// uma lista com contagem", e coisas iguais têm que se parecer.
struct YearsPickerSection: View {
    let years: [Int]
    /// Contagem por ano vinda das facetas do preview (minus-self): "se eu
    /// marcar este ano, dado o resto dos filtros, quantas sobram".
    let counts: [String: Int]
    @Binding var selected: Set<Int>
    let theme: StudyShellTheme
    let onChange: () -> Void

    @State private var sheetOpen = false

    private var summaryText: String {
        if selected.isEmpty { return "Todos (\(years.count))" }
        if selected.count == 1, let only = selected.first { return "\(only)" }
        return "\(selected.count) anos"
    }

    var body: some View {
        QBankFilterRow(
            icon: "calendar",
            title: "ANOS",
            summary: summaryText,
            theme: theme,
            action: { sheetOpen = true }
        )
        .sheet(isPresented: $sheetOpen) {
            YearsPickerSheet(
                years: years,
                counts: counts,
                selected: $selected,
                theme: theme,
                onChange: onChange
            )
            .studyFilterSheet()
        }
    }
}

private struct YearsPickerSheet: View {
    let years: [Int]
    let counts: [String: Int]
    @Binding var selected: Set<Int>
    let theme: StudyShellTheme
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// Mais recente primeiro: é o que o aluno de residência quer ver primeiro.
    private var ordered: [Int] { years.sorted(by: >) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Anos")
                    .font(PixioTypo.cardTitle)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                if !selected.isEmpty {
                    Button("Limpar") {
                        selected.removeAll()
                        onChange()
                    }
                    .font(PixioTypo.caption)
                    .foregroundStyle(theme.primaryLight)
                }
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))  // ds-allow: botão fechar
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.top, VitaTokens.Spacing.lg)
            .padding(.bottom, VitaTokens.Spacing.md)

            Divider().background(VitaColors.glassBorder.opacity(0.4))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(ordered, id: \.self) { year in
                        row(for: year)
                        if year != ordered.last {
                            Divider()
                                .background(VitaColors.glassBorder.opacity(0.3))
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.vertical, VitaTokens.Spacing.xs)
            }
        }
    }

    @ViewBuilder
    private func row(for year: Int) -> some View {
        let isSelected = selected.contains(year)
        let count = counts[String(year)]
        Button {
            if isSelected { selected.remove(year) } else { selected.insert(year) }
            onChange()
        } label: {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))  // ds-allow: caixa de seleção
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textTertiary.opacity(0.55))
                Text(String(year))
                    .font(PixioTypo.sans(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.primaryLight : VitaColors.textPrimary.opacity(0.92))
                    .monospacedDigit()
                Spacer()
                if let count {
                    Text(formatted(count))
                        .font(PixioTypo.caption)
                        .foregroundStyle(VitaColors.textSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatted(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
