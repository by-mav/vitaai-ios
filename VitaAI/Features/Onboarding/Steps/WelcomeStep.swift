import SwiftUI

// MARK: - Welcome Step — University Search

struct WelcomeStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @Binding var showManualEntry: Bool
    @FocusState private var searchFocused: Bool
    @State private var showDropdown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search field
            TextField("Digite sua universidade...", text: $viewModel.universityQuery)
                .foregroundStyle(Color.white.opacity(0.9))
                .font(.system(size: 14))
                .tint(VitaColors.accent)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: viewModel.universityQuery) { newValue in
                    if viewModel.selectedUniversity == nil || newValue != viewModel.selectedUniversity?.shortName {
                        showDropdown = true
                        if newValue.isEmpty { viewModel.selectedUniversity = nil }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(searchFocused ? VitaColors.accent.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )

            // Dropdown results
            let results = viewModel.filteredUniversities.prefix(6)
            if showDropdown && !viewModel.universityQuery.isEmpty && viewModel.selectedUniversity == nil && !results.isEmpty {
                VStack(spacing: 2) {
                    ForEach(Array(results), id: \.id) { (uni: University) in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.selectUniversity(uni)
                            showDropdown = false
                            searchFocused = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(uni.shortName)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.85))
                                        if let enamed = uni.enameConcept, enamed > 0 {
                                            ENAMEDBadge(score: Int(enamed))
                                        }
                                    }
                                    HStack(spacing: 4) {
                                        Text("\(uni.city), \(uni.state)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.3))
                                        if let portals = uni.portals, let p = portals.first {
                                            Text("\u{00B7}")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.white.opacity(0.2))
                                            Text(p.displayName.isEmpty ? University.displayName(for: p.portalType) : p.displayName)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(University.color(for: p.portalType).opacity(0.7))
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity)
            }

            // "Minha faculdade não está aqui"
            if showDropdown && !viewModel.universityQuery.isEmpty && viewModel.selectedUniversity == nil {
                Button {
                    showManualEntry = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text(String(localized: "onboarding_uni_not_found"))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }

            // Selected university badge + semester picker
            if let selected = viewModel.selectedUniversity {
                selectedUniversityBadge(selected)

                // Semester picker
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "onboarding_semester_question"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
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
            }
        }
    }

    private func selectedUniversityBadge(_ selected: University) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(selected.shortName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                    if let enamed = selected.enameConcept, enamed > 0 {
                        ENAMEDBadge(score: Int(enamed))
                    }
                }
                HStack(spacing: 4) {
                    Text("\(selected.city)/\(selected.state)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                    if let portals = selected.portals, !portals.isEmpty {
                        Text("\u{00B7}")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.2))
                        if portals.count > 1 {
                            Text("\(portals.count) portais")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(University.color(for: portals.first?.portalType ?? "").opacity(0.7))
                        } else if let p = portals.first {
                            Text(p.displayName.isEmpty ? University.displayName(for: p.portalType) : p.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(University.color(for: p.portalType).opacity(0.7))
                        }
                    }
                }
            }
            Spacer()
            Button {
                viewModel.clearUniversity()
                showDropdown = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(VitaColors.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.accent.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Manual University Entry Sheet

struct ManualUniversitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = ""
    @State private var state = ""
    var onSubmit: (String, String, String) -> Void

    var body: some View {
        VitaSheet(detents: [.medium]) {
        NavigationStack {
            VStack(spacing: 16) {
                Text(String(localized: "onboarding_add_uni_title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 20)

                Text(String(localized: "onboarding_add_uni_subtitle"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    onboardingTextField("Nome da faculdade", text: $name)
                    onboardingTextField("Cidade", text: $city)
                    onboardingTextField("Estado (UF)", text: $state)
                        .textInputAutocapitalization(.characters)
                }
                .padding(.horizontal, 20)

                Button {
                    guard !name.isEmpty else { return }
                    onSubmit(name, city, state)
                    dismiss()
                } label: {
                    Text(String(localized: "onboarding_add_uni_submit"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VitaColors.surface)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white))
                }
                .padding(.horizontal, 20)
                .disabled(name.isEmpty)
                .opacity(name.isEmpty ? 0.5 : 1)

                Spacer()
            }
            .background(VitaColors.surface.ignoresSafeArea())
        }
        }
    }

    private func onboardingTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .foregroundStyle(Color.white.opacity(0.9))
            .font(.system(size: 14))
            .tint(VitaColors.accent)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
