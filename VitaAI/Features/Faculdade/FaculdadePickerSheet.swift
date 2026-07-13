import SwiftUI

// MARK: - FaculdadePickerSheet
//
// Seletor da faculdade do aluno — lista CANONICA (mesma do onboarding, via
// appData.loadUniversities) + busca. Ao escolher, salva no perfil
// (appData.selectUniversity -> updateProfile) e o hero passa a mostrar o nome.
// Reusa a lista + o save que ja existem, sem duplicar. Rafael 2026-07-13.

struct FaculdadePickerSheet: View {
    @Environment(\.appData) private var appData
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var all: [University] = []
    @State private var loading = true
    @State private var savingId: String?

    private var filtered: [University] {
        let q = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { uni in
            let hay = "\(uni.name) \(uni.shortName) \(uni.city)"
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return hay.contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sua faculdade")
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.textPrimary)

            searchField

            if loading {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { uni in
                            row(uni)
                        }
                        if filtered.isEmpty {
                            Text("Nenhuma faculdade encontrada")
                                .font(VitaTypography.bodySmall)
                                .foregroundStyle(VitaColors.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(20)
        .task {
            all = await appData.loadUniversities("")
            loading = false
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(VitaColors.textTertiary)
            TextField("Buscar faculdade...", text: $query)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VitaColors.glassBg))  // ds-allow: campo de busca
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(VitaColors.glassBorder, lineWidth: 0.5))  // ds-allow: campo de busca
    }

    private func row(_ uni: University) -> some View {
        Button {
            savingId = uni.id
            Task {
                await appData.selectUniversity(uni)
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(uni.displayName)
                            .font(VitaTypography.titleSmall)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)
                        if let e = uni.enameConcept, e > 0 {
                            ENAMEDBadge(score: e)
                        }
                    }
                    Text("\(uni.city) · \(uni.state)")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                if savingId == uni.id {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
