import SwiftUI

struct UniversityStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var searchText = ""

    var filteredSchools: [University] {
        let base = viewModel.filteredUniversities
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.shortName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Sua faculdade")
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.white)

            // State picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    GlassChip(label: "Todos", isSelected: viewModel.selectedState.isEmpty) {
                        viewModel.selectedState = ""
                    }
                    ForEach(allStates, id: \.self) { state in
                        GlassChip(label: state, isSelected: viewModel.selectedState == state) {
                            viewModel.selectedState = state
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Semester picker
            HStack {
                Text("Semestre")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                Spacer()
                Picker("Semestre", selection: $viewModel.selectedSemester) {
                    ForEach(1...12, id: \.self) { sem in
                        Text("\(sem)º").tag(sem)
                    }
                }
                .tint(VitaColors.accent)
            }
            .padding(.horizontal, 20)

            // Search
            GlassTextField(placeholder: "Buscar universidade...", text: $searchText, icon: "magnifyingglass")
                .padding(.horizontal, 20)

            // University list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredSchools) { uni in
                        Button(action: { viewModel.selectedUniversity = uni.name }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(uni.shortName)
                                        .font(VitaTypography.bodyMedium)
                                        .fontWeight(.medium)
                                        .foregroundStyle(VitaColors.textPrimary)
                                    Text("\(uni.city), \(uni.state)")
                                        .font(VitaTypography.bodySmall)
                                        .foregroundStyle(VitaColors.textTertiary)
                                }
                                Spacer()
                                if viewModel.selectedUniversity == uni.name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(VitaColors.accent)
                                }
                            }
                            .padding(14)
                            .glassCard(cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
