import SwiftUI

struct SubjectsStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var customFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 24)

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("O que está cursando?")
                        .font(VitaTypography.bodyLarge)
                        .foregroundStyle(VitaColors.textPrimary)

                    Text("Selecione suas matérias atuais")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer().frame(height: 20)

                // Chip flow: semester subjects + any added custom subjects
                FlowLayout(spacing: 8) {
                    // Standard semester subjects
                    ForEach(viewModel.semesterSubjects, id: \.self) { subject in
                        SubjectChip(
                            label: subject,
                            isSelected: viewModel.selectedSubjects.contains(subject)
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.toggleSubject(subject)
                        }
                    }
                    // Custom subjects not in semester list
                    ForEach(viewModel.selectedSubjects.filter { !viewModel.semesterSubjects.contains($0) }, id: \.self) { subject in
                        SubjectChip(
                            label: subject,
                            isSelected: true
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.toggleSubject(subject)
                        }
                    }
                }

                Spacer().frame(height: 20)

                // Add custom subject
                VStack(alignment: .leading, spacing: 8) {
                    Text("Adicionar outra")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)

                    HStack(spacing: 12) {
                        TextField("Nome da matéria", text: $viewModel.customSubject)
                            .foregroundStyle(VitaColors.textPrimary)
                            .font(VitaTypography.bodyLarge)
                            .tint(VitaColors.accent)
                            .focused($customFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.addCustomSubject()
                                customFocused = false
                            }

                        if !viewModel.customSubject.isEmpty {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.addCustomSubject()
                                customFocused = false
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(VitaColors.accent)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.7)))
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.customSubject.isEmpty)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(VitaColors.glassBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                customFocused ? VitaColors.accent.opacity(0.5) : VitaColors.glassBorder,
                                lineWidth: 1
                            )
                    )
                    .animation(.easeInOut(duration: 0.15), value: customFocused)
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { customFocused = false }
    }
}

// MARK: - Subject chip

private struct SubjectChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? VitaColors.accent.opacity(0.12) : VitaColors.glassBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? VitaColors.accent.opacity(0.6) : VitaColors.glassBorder,
                            lineWidth: 1
                        )
                )
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FlowLayout (wrapping chip layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
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
