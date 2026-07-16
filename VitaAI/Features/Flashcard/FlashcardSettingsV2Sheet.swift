import SwiftUI

/// Config de estudo do flashcard (Anki v2). Espelha as opções de deck do Anki.
/// Retorno de GET/PATCH /api/study/flashcards/settings. Defaults = FSRS padrão.
struct FlashcardStudySettings: Codable, Equatable {
    var newPerDay: Int = 20
    var maxReviewsPerDay: Int = 200
    var desiredRetention: Double = 0.9
    var newCardOrder: String = "random"   // random | sequential
    var burySiblings: Bool = false
    var maximumInterval: Int = 36500
    var showTimer: Bool = false
}

/// Config de estudo do flashcard (Anki v2). Lê/salva em /api/study/flashcards/settings.
/// Retenção (FSRS), novos/dia, máx revisões/dia, ordem, enterrar irmãos, cronômetro.
/// Espelha as opções de deck do Anki (alta prioridade do gap). Rafael 2026-07-10.
struct FlashcardSettingsV2Sheet: View {
    @Environment(\.appContainer) private var container

    @State private var settings = FlashcardStudySettings()
    @State private var loaded = FlashcardStudySettings()
    @State private var saveTask: Task<Void, Never>?
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        VitaSheet(title: "Ajustes de estudo", detents: [.large]) {
            Group {
                if isLoading {
                    VitaMascotEquipped(state: .thinking, size: 88)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    errorState(err)
                } else {
                    form
                }
            }
        }
        .task { await load() }
        .onChange(of: settings) { newValue in
            // Cancela SEMPRE o save pendente (mesmo se o valor voltar ao carregado),
            // senao um debounce stale dispara depois e sobrescreve o valor certo.
            saveTask?.cancel()
            // Usa newValue (nao a @State settings, que pode estar stale no closure).
            guard !isLoading, newValue != loaded else { return }
            saveTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                let saved = try? await container.api.updateFlashcardSettings(newValue)
                // Atualiza o baseline persistido: o guard passa a comparar contra o
                // ultimo estado salvo, nao o do GET inicial.
                if let saved, !Task.isCancelled {
                    await MainActor.run { loaded = saved }
                }
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing._2xl) {
                retentionSection
                dailyLimitsSection
                orderSection
                togglesSection
            }
            .padding(.horizontal, VitaTokens.Spacing.xl)
            .padding(.top, VitaTokens.Spacing.md)
            .padding(.bottom, VitaTokens.Spacing._3xl)
        }
    }

    // MARK: - Retenção (FSRS)

    private var retentionSection: some View {
        card(title: "Retenção desejada", subtitle: "Quanto você quer lembrar quando revisa. Mais alto = mais revisões.") {
            VStack(spacing: VitaTokens.Spacing.sm) {
                HStack {
                    Text("\(Int((settings.desiredRetention * 100).rounded()))%")
                        .font(VitaTypography.headlineSmall)
                        .foregroundStyle(VitaColors.accent)
                    Spacer()
                    Text(retentionHint)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                Slider(value: $settings.desiredRetention, in: 0.70...0.97, step: 0.01)
                    .tint(VitaColors.accent)
            }
        }
    }

    private var retentionHint: String {
        switch settings.desiredRetention {
        case ..<0.83: return "menos revisões"
        case 0.92...: return "mais revisões"
        default: return "equilibrado"
        }
    }

    // MARK: - Limites diários

    private var dailyLimitsSection: some View {
        card(title: "Limites diários", subtitle: "Ritmo de estudo por dia.") {
            VStack(spacing: VitaTokens.Spacing.md) {
                stepperRow(label: "Cartões novos por dia", value: $settings.newPerDay, range: 0...999, step: 5)
                Divider().overlay(VitaColors.glassBorder.opacity(0.5))
                stepperRow(label: "Máximo de revisões por dia", value: $settings.maxReviewsPerDay, range: 0...9999, step: 10)
            }
        }
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
        HStack {
            Text(label)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textPrimary)
            Spacer(minLength: VitaTokens.Spacing.md)
            HStack(spacing: VitaTokens.Spacing.md) {
                stepButton(icon: "minus") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                }
                Text("\(value.wrappedValue)")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.accent)
                    .frame(minWidth: 44)
                stepButton(icon: "plus") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                }
            }
        }
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))  // ds-allow: ícone stepper (área de toque)
                .foregroundStyle(VitaColors.textSecondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(VitaColors.glassBg))
                .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ordem dos novos

    private var orderSection: some View {
        card(title: "Ordem dos cartões novos", subtitle: nil) {
            HStack(spacing: VitaTokens.Spacing.sm) {
                orderPill(value: "random", label: "Aleatório")
                orderPill(value: "sequential", label: "Sequencial")
            }
        }
    }

    private func orderPill(value: String, label: String) -> some View {
        let isSel = settings.newCardOrder == value
        return Button { settings.newCardOrder = value } label: {
            Text(label)
                .font(VitaTypography.labelMedium)
                .foregroundStyle(isSel ? VitaColors.surface : VitaColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, VitaTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                        .fill(isSel ? VitaColors.accent : VitaColors.glassBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                        .stroke(isSel ? Color.clear : VitaColors.glassBorder, lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toggles

    private var togglesSection: some View {
        card(title: "Mais", subtitle: nil) {
            VStack(spacing: VitaTokens.Spacing.md) {
                toggleRow(label: "Enterrar irmãos", hint: "Não mostrar 2 cartões do mesmo material no mesmo dia", isOn: $settings.burySiblings)
                Divider().overlay(VitaColors.glassBorder.opacity(0.5))
                toggleRow(label: "Mostrar cronômetro", hint: "Tempo na sessão de estudo", isOn: $settings.showTimer)
            }
        }
    }

    private func toggleRow(label: String, hint: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(VitaTypography.bodyMedium).foregroundStyle(VitaColors.textPrimary)
                Text(hint).font(VitaTypography.labelSmall).foregroundStyle(VitaColors.textTertiary)
            }
            Spacer(minLength: VitaTokens.Spacing.md)
            Toggle("", isOn: isOn).labelsHidden().tint(VitaColors.accent)
        }
    }

    // MARK: - Card shell

    private func card<Content: View>(title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))  // ds-allow: label de seção (kerning)
                    .kerning(0.5)
                    .foregroundStyle(VitaColors.sectionLabel)
                if let subtitle {
                    Text(subtitle).font(VitaTypography.labelSmall).foregroundStyle(VitaColors.textTertiary)
                }
            }
            content()
                .padding(VitaTokens.Spacing.lg)
                .glassCard(cornerRadius: VitaTokens.Radius.lg)
        }
    }

    private func errorState(_ err: String) -> some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            Text(err).font(VitaTypography.bodyMedium).foregroundStyle(VitaColors.textSecondary).multilineTextAlignment(.center)
            Button("Tentar novamente") { Task { await load() } }.foregroundStyle(VitaColors.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(VitaTokens.Spacing._3xl)
    }

    private func load() async {
        isLoading = true; loadError = nil
        do { let fetched = try await container.api.getFlashcardSettings(); settings = fetched; loaded = fetched }
        catch { loadError = "Não foi possível carregar os ajustes." }
        isLoading = false
    }
}
