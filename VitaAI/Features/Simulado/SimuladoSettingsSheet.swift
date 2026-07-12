import SwiftUI

// MARK: - SimuladoSettingsSheet — Ajustes do simulado (issue #189)
//
// Gaveta de configuracao no padrao das 3 ferramentas de estudo (espelho da
// FlashcardSettingsV2Sheet): cronometro + quantidade saem do corpo do builder
// (Rafael 2026-07-12: "tela com N blocos — iguala ao flashcards"). Le e grava
// direto no MESMO SimuladoBuilderViewModel — nenhuma config decorativa.

struct SimuladoSettingsSheet: View {
    let vm: SimuladoBuilderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VitaSheet(title: "Ajustes do simulado") {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing._3xl) {
                timerSection
                quantitySection
                Spacer(minLength: 0)
            }
            .padding(.horizontal, VitaTokens.Spacing._2xl)
            .padding(.top, VitaTokens.Spacing.lg)
        }
    }

    // MARK: - Cronometro (movido do SimuladoBuilderScreen — spec §11.3)

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            Text("CRONÔMETRO")
                .font(VitaTypography.labelSmall)
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            Text("Simulado com tempo, como na prova real.")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)

            VitaGlassCard(cornerRadius: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: 13, weight: .medium))  // ds-allow: movido do builder (pre-existente)
                            .foregroundStyle(StudyShellTheme.simulados.primaryLight.opacity(0.9))
                        Text("Limite de tempo")
                            .font(VitaTypography.titleMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { vm.state.timerEnabled },
                            set: { vm.setTimerEnabled($0) }
                        ))
                        .labelsHidden()
                        .tint(StudyShellTheme.simulados.primaryLight)
                    }

                    if vm.state.timerEnabled {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([15, 30, 60, 90, 120, 180], id: \.self) { mins in
                                    let isSelected = vm.state.timerMinutes == mins
                                    Button {
                                        vm.setTimerMinutes(mins)
                                    } label: {
                                        Text("\(mins) min")
                                            .font(VitaTypography.labelMedium)
                                            .foregroundStyle(isSelected
                                                ? StudyShellTheme.simulados.primaryLight
                                                : VitaColors.textSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(
                                                Capsule().fill(isSelected
                                                    ? StudyShellTheme.simulados.primary.opacity(0.22)
                                                    : Color.clear)
                                            )
                                            .overlay(
                                                Capsule().stroke(isSelected
                                                    ? StudyShellTheme.simulados.primaryLight.opacity(0.32)
                                                    : VitaColors.glassBorder, lineWidth: 0.75)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        Text("Sem limite de tempo — modo livre")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
                .padding(14)
            }
        }
    }

    // MARK: - Quantidade (movida do SimuladoBuilderScreen)

    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            Text("QUANTIDADE")
                .font(VitaTypography.labelSmall)
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            StudyAmountSliderCard(
                title: "Questões por simulado",
                value: vm.state.questionCount,
                range: 10...200,
                step: 10,
                theme: .simulados,
                valueSuffix: "questões",
                presets: [20, 30, 50, 100, 200],
                onChange: { vm.setQuestionCount($0) }
            )
        }
    }
}
