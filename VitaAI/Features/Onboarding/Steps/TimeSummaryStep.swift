import SwiftUI

struct TimeSummaryStep: View {
    @Bindable var viewModel: OnboardingViewModel

    private struct TimeOption: Identifiable {
        let id: Int // minutes
        let label: String
        let sublabel: String
    }

    private let options: [TimeOption] = [
        TimeOption(id: 30,  label: "30 min",  sublabel: "Sessões curtas"),
        TimeOption(id: 60,  label: "1 hora",  sublabel: "Ritmo moderado"),
        TimeOption(id: 120, label: "2 horas", sublabel: "Estudo intenso"),
        TimeOption(id: 180, label: "3h+",     sublabel: "Dedicação máxima"),
    ]

    private let goalLabels: [String: String] = [
        "provas":     "Provas",
        "residencia": "Residência",
        "aprender":   "Aprender",
        "organizar":  "Organizar",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 24)

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quanto tempo por dia?")
                        .font(VitaTypography.bodyLarge)
                        .foregroundStyle(VitaColors.textPrimary)

                    Text("Planejamos suas sessões de estudo")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer().frame(height: 20)

                // 2×2 time grid
                VStack(spacing: 10) {
                    ForEach(0..<2) { row in
                        HStack(spacing: 10) {
                            ForEach(0..<2) { col in
                                let option = options[row * 2 + col]
                                TimeCard(
                                    label: option.label,
                                    sublabel: option.sublabel,
                                    isSelected: viewModel.dailyStudyMinutes == option.id
                                ) {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.dailyStudyMinutes = option.id
                                }
                            }
                        }
                    }
                }

                Spacer().frame(height: 32)

                // Summary card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Resumo")
                        .font(VitaTypography.bodyLarge)
                        .fontWeight(.medium)
                        .foregroundStyle(VitaColors.textPrimary)

                    VStack(spacing: 0) {
                        let rows = summaryRows
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            SummaryRow(label: row.0, value: row.1)
                            if index < rows.count - 1 {
                                Divider()
                                    .background(VitaColors.glassBorder)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(VitaColors.glassBg)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, Color.white.opacity(0.06), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                    }
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Summary rows (dynamic — only show filled data)

    private var summaryRows: [(String, String)] {
        var rows: [(String, String)] = []
        let name = viewModel.nickname.trimmingCharacters(in: .whitespaces)
        rows.append(("Nome", name.isEmpty ? "—" : name))

        if let uni = viewModel.selectedUniversity {
            rows.append(("Faculdade", uni.shortName))
        }
        if viewModel.selectedSemester > 0 {
            rows.append(("Período", "\(viewModel.selectedSemester)° semestre"))
        }
        if !viewModel.selectedSubjects.isEmpty {
            rows.append(("Matérias", "\(viewModel.selectedSubjects.count) selecionadas"))
        }
        if !viewModel.selectedGoals.isEmpty {
            let labels = viewModel.selectedGoals.compactMap { goalLabels[$0] }.joined(separator: ", ")
            rows.append(("Foco", labels.isEmpty ? "—" : labels))
        }
        if viewModel.dailyStudyMinutes > 0 {
            let timeLabel: String
            switch viewModel.dailyStudyMinutes {
            case 30:  timeLabel = "30 min/dia"
            case 60:  timeLabel = "1h/dia"
            case 120: timeLabel = "2h/dia"
            default:  timeLabel = "3h+/dia"
            }
            rows.append(("Tempo", timeLabel))
        }
        return rows
    }
}

// MARK: - Time card

private struct TimeCard: View {
    let label: String
    let sublabel: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(VitaTypography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.white)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)

                Text(sublabel)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(isSelected ? VitaColors.accent.opacity(0.10) : VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? VitaColors.accent.opacity(0.5) : VitaColors.glassBorder,
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary row

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
            Spacer()
            Text(value)
                .font(VitaTypography.bodyMedium)
                .fontWeight(.medium)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, 5)
    }
}
