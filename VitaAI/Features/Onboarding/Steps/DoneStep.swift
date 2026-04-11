import SwiftUI

// MARK: - Done Content (completion summary with real sync data)

struct DoneStep: View {
    let userName: String
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Subtitle
            Text(String(localized: "onboarding_done_subtitle"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 16)

            // +50 XP badge
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                Text("+50 XP")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(VitaColors.accentLight.opacity(0.9))
            .padding(.horizontal, 14).padding(.vertical, 5)
            .background(
                Capsule().fill(VitaColors.accent.opacity(0.15))
                    .overlay(Capsule().stroke(VitaColors.accent.opacity(0.25), lineWidth: 1))
            )
            .padding(.bottom, 20)

            // Stats row — real data from sync
            HStack(spacing: 24) {
                let subjectsCount = viewModel.syncedSubjects.count
                let gradesCount = viewModel.syncGrades
                let semester = viewModel.selectedSemester

                if subjectsCount > 0 {
                    DoneStat(value: "\(subjectsCount)", label: "Matérias")
                }
                if gradesCount > 0 {
                    DoneStat(value: "\(gradesCount)", label: "Notas")
                }
                if viewModel.syncSchedule > 0 {
                    DoneStat(value: "\(viewModel.syncSchedule)", label: "Horários")
                }
                if semester > 0 {
                    DoneStat(value: "\(semester)\u{00BA}", label: "Semestre")
                }
                // If nothing was synced, show university
                if subjectsCount == 0 && gradesCount == 0 && viewModel.syncSchedule == 0 {
                    if let uni = viewModel.selectedUniversity {
                        DoneStat(value: uni.shortName, label: "Universidade")
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct DoneStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(VitaColors.accentLight.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}
