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

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
                            if trimmedQuery.count >= 2 {
                                notFoundCard
                            } else {
                                Text("Nenhuma faculdade encontrada")
                                    .font(VitaTypography.bodySmall)
                                    .foregroundStyle(VitaColors.textTertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 24)
                            }
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

    // "Meu curso nao esta aqui": o aluno adiciona com o nome que ele usa
    // (fica salvo pra ele) E a sugestao vai pra equipe (university_requests
    // -> PULSE) canonizar depois. Rafael 2026-07-13.
    private var notFoundCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meu curso não está aqui")
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary)
            Text("Adicione com o nome que você usa — fica salvo pra você e a gente inclui na lista oficial.")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                let name = trimmedQuery
                savingId = "__custom__"
                Task {
                    await appData.addCustomFaculty(name: name)
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    if savingId == "__custom__" {
                        ProgressView().tint(VitaColors.surface)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text("Adicionar “\(trimmedQuery)”")
                        .font(VitaTypography.labelMedium)
                        .lineLimit(1)
                }
                .foregroundStyle(VitaColors.surface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VitaColors.accent))  // ds-allow: CTA adicionar meu curso
            }
            .buttonStyle(.plain)
            .disabled(savingId == "__custom__")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VitaColors.glassBg))  // ds-allow: card meu curso nao esta aqui
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VitaColors.glassBorder, lineWidth: 0.5))  // ds-allow: card meu curso nao esta aqui
        .padding(.top, 14)
    }
}
