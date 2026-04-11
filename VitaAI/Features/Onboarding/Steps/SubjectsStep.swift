import SwiftUI

// MARK: - Subjects Content (difficulty selection — data from API sync)

struct SubjectsStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 8) {
            if viewModel.syncedSubjects.isEmpty {
                // No subjects found — show empty state
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.15))
                    Text(String(localized: "onboarding_subjects_empty"))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.35))
                    Text(String(localized: "onboarding_subjects_empty_hint"))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.2))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
            } else {
                ForEach(viewModel.syncedSubjects) { subject in
                    let difficulty = viewModel.subjectDifficulties[subject.name]
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(subject.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(2)
                            Text(subject.source == "canvas" ? "Canvas" : "WebAluno")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            DifficultyPill(label: "Fácil", selected: difficulty == "facil") {
                                viewModel.setDifficulty(subject.name, difficulty: "facil")
                            }
                            DifficultyPill(label: "Medio", selected: difficulty == "medio") {
                                viewModel.setDifficulty(subject.name, difficulty: "medio")
                            }
                            DifficultyPill(label: "Difícil", selected: difficulty == "dificil") {
                                viewModel.setDifficulty(subject.name, difficulty: "dificil")
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    )
                }
            }
        }
    }
}

// MARK: - Difficulty Pill

private struct DifficultyPill: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    private var activeColor: Color {
        switch label.lowercased() {
        case "facil": return Color(red: 0.51, green: 0.78, blue: 0.55)
        case "medio": return Color(red: 1.0, green: 0.71, blue: 0.31)
        default: return Color(red: 1.0, green: 0.39, blue: 0.31)
        }
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(selected ? activeColor.opacity(0.85) : .white.opacity(0.25))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? activeColor.opacity(0.12) : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selected ? activeColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
