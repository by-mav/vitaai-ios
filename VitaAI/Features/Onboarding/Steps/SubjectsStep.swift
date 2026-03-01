import SwiftUI

struct SubjectsStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Suas disciplinas")
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.white)

            Text("Semestre \(viewModel.selectedSemester) — selecione as que está cursando")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)

            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.semesterSubjects, id: \.self) { subject in
                        GlassChip(
                            label: subject,
                            isSelected: viewModel.selectedSubjects.contains(subject)
                        ) {
                            viewModel.toggleSubject(subject)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Text("\(viewModel.selectedSubjects.count) selecionadas")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)
        }
    }
}

// Simple flow layout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
