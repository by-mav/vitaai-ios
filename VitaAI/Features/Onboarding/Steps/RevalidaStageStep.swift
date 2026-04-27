import SwiftUI

// MARK: - RevalidaStageStep — P3 do onboarding v2 (Onda 5b, slice 1)
//
// So aparece se viewModel.selectedGoal == .revalida.
// Captura `currentStage` (PRIMEIRA/SEGUNDA) + `focusAreas` opcionais (chips).
//
// REVALIDA-INEP tem 2 etapas:
//   - PRIMEIRA: prova teorica (90 questoes objetivas + redacao + 5 discursivas)
//   - SEGUNDA: habilidades clinicas (estacoes OSCE)

struct RevalidaStageStep: View {
    @Bindable var viewModel: OnboardingViewModel

    // Areas focais alinhadas com great-areas + grandes especialidades clinicas
    private let focusAreaOptions: [(slug: String, label: String)] = [
        ("clinica-medica", "Clinica Medica"),
        ("cirurgia", "Cirurgia"),
        ("ginecologia-obstetricia", "G.O."),
        ("pediatria", "Pediatria"),
        ("medicina-familia", "MFC"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Stage selector
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "onboarding_revalida_stage_question"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 10) {
                    stageButton(stage: .primeira, label: String(localized: "onboarding_revalida_stage_primeira"))
                    stageButton(stage: .segunda, label: String(localized: "onboarding_revalida_stage_segunda"))
                }
            }

            // Focus areas (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "onboarding_revalida_focus_question"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Text(String(localized: "onboarding_revalida_focus_hint"))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))

                FlowLayout(spacing: 8) {
                    ForEach(focusAreaOptions, id: \.slug) { area in
                        focusChip(slug: area.slug, label: area.label)
                    }
                }
            }
        }
    }

    private func stageButton(stage: RevalidaStage, label: String) -> some View {
        let isSelected = viewModel.revalidaStage == stage
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.revalidaStage = stage
        } label: {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? VitaColors.accent : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? VitaColors.accent.opacity(0.12) : Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? VitaColors.accent.opacity(0.30) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func focusChip(slug: String, label: String) -> some View {
        let isSelected = viewModel.revalidaFocusAreas.contains(slug)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isSelected {
                viewModel.revalidaFocusAreas.removeAll { $0 == slug }
            } else {
                viewModel.revalidaFocusAreas.append(slug)
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? VitaColors.accent : .white.opacity(0.55))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? VitaColors.accent.opacity(0.12) : Color.white.opacity(0.03))
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? VitaColors.accent.opacity(0.30) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// FlowLayout (chip wrapper) lives in DesignSystem/Components/FlowLayout.swift
// Same default spacing (8). No local redeclaration — see commit 43d4bde.
