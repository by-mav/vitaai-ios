import SwiftUI

struct UniversityStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var searchFocused: Bool
    @State private var showDropdown = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 24)

                // Section: University search
                VStack(alignment: .leading, spacing: 4) {
                    Text("Onde você estuda?")
                        .font(VitaTypography.bodyLarge)
                        .foregroundStyle(VitaColors.textPrimary)

                    Text("Busque sua faculdade de medicina")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer().frame(height: 16)

                // Search field
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(width: 20)

                    TextField("Nome ou sigla da faculdade", text: $viewModel.universityQuery)
                        .foregroundStyle(VitaColors.textPrimary)
                        .font(VitaTypography.bodyLarge)
                        .tint(VitaColors.accent)
                        .focused($searchFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onChange(of: viewModel.universityQuery) { _, newValue in
                            // If user is typing (not just programmatic set after selection), show dropdown
                            if viewModel.selectedUniversity == nil || newValue != viewModel.selectedUniversity?.shortName {
                                showDropdown = true
                                if newValue.isEmpty {
                                    viewModel.selectedUniversity = nil
                                }
                            }
                        }
                        .onSubmit { searchFocused = false }

                    if !viewModel.universityQuery.isEmpty {
                        Button(action: {
                            viewModel.clearUniversity()
                            showDropdown = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(VitaColors.glassBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            searchFocused ? VitaColors.accent.opacity(0.5) : VitaColors.glassBorder,
                            lineWidth: 1
                        )
                )
                .animation(.easeInOut(duration: 0.15), value: searchFocused)

                // Autocomplete dropdown
                let dropdownResults = viewModel.filteredUniversities.prefix(6)
                if showDropdown && !viewModel.universityQuery.isEmpty && viewModel.selectedUniversity == nil && !dropdownResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(dropdownResults)) { uni in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.selectUniversity(uni)
                                showDropdown = false
                                searchFocused = false
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(uni.shortName)
                                            .font(VitaTypography.bodyMedium)
                                            .fontWeight(.medium)
                                            .foregroundStyle(VitaColors.textPrimary)
                                        Text("\(uni.name) — \(uni.city)/\(uni.state)")
                                            .font(VitaTypography.bodySmall)
                                            .foregroundStyle(VitaColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            if uni.id != dropdownResults.last?.id {
                                Divider()
                                    .background(VitaColors.glassBorder)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(VitaColors.glassBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: showDropdown)
                }

                // Selected university badge
                if let selected = viewModel.selectedUniversity {
                    Spacer().frame(height: 8)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.shortName)
                                .font(VitaTypography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundStyle(VitaColors.accent)
                            Text("\(selected.city)/\(selected.state)")
                                .font(VitaTypography.bodySmall)
                                .foregroundStyle(VitaColors.textSecondary)
                        }
                        Spacer()
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.clearUniversity()
                            showDropdown = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(VitaColors.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.accent.opacity(0.3), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selected.id)
                }

                Spacer().frame(height: 28)

                // Section: Semester selection
                VStack(alignment: .leading, spacing: 4) {
                    Text("Qual período?")
                        .font(VitaTypography.bodyLarge)
                        .foregroundStyle(VitaColors.textPrimary)

                    Text("Semestre atual do curso")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer().frame(height: 12)

                // 3×4 semester chip grid
                VStack(spacing: 8) {
                    ForEach(0..<4) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<3) { col in
                                let sem = row * 3 + col + 1
                                SemesterChip(
                                    label: "\(sem)°",
                                    isSelected: viewModel.selectedSemester == sem
                                ) {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.selectSemester(sem)
                                }
                            }
                        }
                    }
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            searchFocused = false
            if viewModel.universityQuery.isEmpty {
                showDropdown = false
            }
        }
    }
}

// MARK: - Semester chip

private struct SemesterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
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
