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
    private var focusAreaOptions: [(slug: String, label: String)] {
        [
            ("clinica-medica", String(localized: "onboarding_focus_clinical_medicine")),
            ("cirurgia", String(localized: "onboarding_focus_surgery")),
            ("ginecologia-obstetricia", String(localized: "onboarding_focus_obgyn")),
            ("pediatria", String(localized: "onboarding_focus_pediatrics")),
            ("medicina-familia", String(localized: "onboarding_focus_family_medicine")),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Stage selector
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "onboarding_revalida_stage_question"))
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary.opacity(0.68))

                OnboardingChoiceRow(
                    title: String(localized: "onboarding_revalida_stage_primeira"),
                    systemImage: "doc.text",
                    isSelected: viewModel.revalidaStage == .primeira,
                    accessibilityIdentifier: "onboardingRevalidaPrimeira"
                ) {
                    viewModel.revalidaStage = .primeira
                }
                OnboardingChoiceRow(
                    title: String(localized: "onboarding_revalida_stage_segunda"),
                    systemImage: "person.2.badge.gearshape",
                    isSelected: viewModel.revalidaStage == .segunda,
                    accessibilityIdentifier: "onboardingRevalidaSegunda"
                ) {
                    viewModel.revalidaStage = .segunda
                }
            }

            // Focus areas (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "onboarding_revalida_focus_question"))
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary.opacity(0.68))
                Text(String(localized: "onboarding_revalida_focus_hint"))
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textPrimary.opacity(0.48))

                FlowLayout(spacing: 8) {
                    ForEach(focusAreaOptions, id: \.slug) { area in
                        focusChip(slug: area.slug, label: area.label)
                    }
                }
            }
        }
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
                .font(VitaTypography.labelMedium)
                .foregroundStyle(
                    isSelected
                        ? VitaColors.accent
                        : VitaColors.textPrimary.opacity(0.66)
                )
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
