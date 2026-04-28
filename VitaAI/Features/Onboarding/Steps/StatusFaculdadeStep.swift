import SwiftUI

// MARK: - StatusFaculdadeStep — P2 do onboarding v2 (Onda 5b, Rafael 2026-04-27)
//
// Pergunta: "Voce esta cursando faculdade de medicina?"
// Resposta vira `viewModel.inFaculdade` (yes/graduated/skip).
// Se "yes", precisa tambem de `selectedSemester` (1-12).
//
// Apos esta tela, o GoalStep filtra os goals validos com base nessa resposta.

struct StatusFaculdadeStep: View {
    @Bindable var viewModel: OnboardingViewModel

    private let semesterColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // 3 buttons: yes / graduated / skip
            VStack(spacing: 10) {
                statusOption(
                    status: .yes,
                    title: String(localized: "onboarding_status_yes"),
                    subtitle: String(localized: "onboarding_status_yes_sub")
                )
                statusOption(
                    status: .graduated,
                    title: String(localized: "onboarding_status_graduated"),
                    subtitle: String(localized: "onboarding_status_graduated_sub")
                )
                statusOption(
                    status: .skip,
                    title: String(localized: "onboarding_status_skip"),
                    subtitle: String(localized: "onboarding_status_skip_sub")
                )
            }

            // Semester picker — only shown if user picked "yes"
            if viewModel.inFaculdade == .yes {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "onboarding_semester_question"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)

                    LazyVGrid(columns: semesterColumns, spacing: 8) {
                        ForEach(1...12, id: \.self) { sem in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.selectSemester(sem)
                            } label: {
                                Text("\(sem)\u{00BA}")
                                    .font(.system(size: 13, weight: viewModel.selectedSemester == sem ? .bold : .medium))
                                    .foregroundStyle(viewModel.selectedSemester == sem ? VitaColors.accent : .white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(viewModel.selectedSemester == sem ? VitaColors.accent.opacity(0.15) : Color.white.opacity(0.03))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(viewModel.selectedSemester == sem ? VitaColors.accent.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.inFaculdade)
    }

    private func statusOption(status: InFaculdadeStatus, title: String, subtitle: String) -> some View {
        let isSelected = viewModel.inFaculdade == status
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.inFaculdade = status
            // Reset semester if user switches away from "yes"
            if status != .yes { viewModel.selectedSemester = 0 }
            // Reset goal — filtragem mudou
            viewModel.selectedGoal = nil
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? VitaColors.accent : Color.white.opacity(0.18), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(VitaColors.accent)
                            .frame(width: 9, height: 9)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? VitaColors.accent.opacity(0.10) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? VitaColors.accent.opacity(0.30) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
