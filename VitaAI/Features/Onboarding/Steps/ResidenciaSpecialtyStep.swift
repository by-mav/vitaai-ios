import SwiftUI

// MARK: - ResidenciaSpecialtyStep — P3 RESIDENCIA (Onda 5b Slice 4, Rafael 2026-04-27)
//
// Aparece apenas se viewModel.selectedGoal == .residencia.
// Captura:
//   - targetSpecialtySlug: slug de medical_specialties (obrigatorio)
//   - targetInstitutions: array opcional de instituicoes alvo
//
// Lista vem de GET /api/medical-specialties (Onda 5a backend, 63 entries CNRM/MEC).
// Agrupado em 2 secoes: Acesso Direto (22) e Com Pre-requisito (41).
// Decisao Rafael 2026-04-27: dropdown agrupado (mais clean que lista flat de 63).

struct ResidenciaSpecialtyStep: View {
    @Bindable var viewModel: OnboardingViewModel
    var api: VitaAPI?
    var onSelect: (MedicalSpecialty) -> Void

    @State private var directAccess: [MedicalSpecialty] = []
    @State private var withPrerequisite: [MedicalSpecialty] = []
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var query = ""

    private var filteredDirect: [MedicalSpecialty] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return directAccess }
        return directAccess.filter { $0.name.lowercased().contains(q) }
    }

    private var filteredPrereq: [MedicalSpecialty] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return withPrerequisite }
        return withPrerequisite.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            OnboardingTextInput(
                value: $query,
                placeholder: String(localized: "onboarding_residencia_search_placeholder"),
                leadingSystemImage: "magnifyingglass",
                autocapitalization: .words,
                autocorrectionDisabled: true,
                accessibilityIdentifier: "onboardingSpecialtySearch"
            )

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(VitaColors.accent)
                    Spacer()
                }
                .padding(.vertical, 32)
            } else if let err = loadError {
                Text(err)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.dataRed)
            } else {
                // Acesso Direto (22)
                if !filteredDirect.isEmpty {
                    sectionHeader(
                        title: String(localized: "onboarding_residencia_section_direct"),
                        count: filteredDirect.count
                    )
                    LazyVStack(spacing: 6) {
                        ForEach(filteredDirect) { spec in
                            specialtyRow(spec)
                        }
                    }
                }

                // Com Pre-requisito (41)
                if !filteredPrereq.isEmpty {
                    sectionHeader(
                        title: String(localized: "onboarding_residencia_section_prereq"),
                        count: filteredPrereq.count
                    )
                    LazyVStack(spacing: 6) {
                        ForEach(filteredPrereq) { spec in
                            specialtyRow(spec)
                        }
                    }
                }
            }
        }
        .task {
            await loadSpecialties()
        }
    }

    // MARK: - Sub-views

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.textPrimary.opacity(0.72))
            Spacer()
            Text("\(count)")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textPrimary.opacity(0.56))
        }
        .padding(.top, 8)
    }

    private func specialtyRow(_ spec: MedicalSpecialty) -> some View {
        let isSelected = viewModel.targetSpecialtySlug == spec.slug
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.targetSpecialtySlug = spec.slug
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
            onSelect(spec)
        } label: {
            HStack(spacing: 12) {
                Text(spec.name)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(
                        isSelected
                            ? VitaColors.textPrimary
                            : VitaColors.textPrimary.opacity(0.78)
                    )
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? VitaColors.accent.opacity(0.10) : Color.white.opacity(0.025))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? VitaColors.accent.opacity(0.30) : Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboardingSpecialty_\(spec.slug)")
    }

    // MARK: - Data loading

    private func loadSpecialties() async {
        guard let api else {
            loadError = String(localized: "onboarding_residencia_api_unavailable")
            isLoading = false
            return
        }
        do {
            let resp = try await api.getMedicalSpecialties()
            directAccess = resp.directAccess
            withPrerequisite = resp.withPrerequisite
            isLoading = false
        } catch {
            loadError = String(localized: "onboarding_residencia_load_error")
            isLoading = false
            print("[ResidenciaSpecialty] load failed: \(error)")
        }
    }
}
