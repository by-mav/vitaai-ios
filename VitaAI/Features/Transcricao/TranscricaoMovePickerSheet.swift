import SwiftUI

/// Sheet pra mover uma gravação pra uma disciplina do aluno (ou remover).
///
/// Fonte: `academic_subjects` via `appData.gradesResponse` (mesmo que o chip
/// picker do recorder). Persiste via PATCH `/api/studio/sources/:id` em
/// `metadata.disciplineSlug`. Sem disciplina = rascunho solto.
struct TranscricaoMovePickerSheet: View {
    let currentSlug: String?
    let onPick: (String?) -> Void

    @Environment(\.appData) private var appData
    @Environment(\.dismiss) private var dismiss

    private var subjects: [(slug: String, name: String)] {
        let current = appData.gradesResponse?.current ?? []
        let completed = appData.gradesResponse?.completed ?? []
        return (current + completed)
            .compactMap { s in
                guard !s.subjectName.isEmpty else { return nil }
                // grades endpoint usa `id` como slug/id da disciplina — o
                // backend aceita qualquer string consistente aqui; usaremos
                // o próprio subjectName slugificado como chave.
                let slug = s.subjectName
                    .lowercased()
                    .folding(options: .diacriticInsensitive, locale: .init(identifier: "pt_BR"))
                    .replacingOccurrences(of: " ", with: "-")
                    .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                return (slug: slug, name: s.subjectName)
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onPick(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "tray")
                                .foregroundStyle(Color.white.opacity(0.55))
                            Text("Sem disciplina (rascunho)")
                                .foregroundStyle(Color.white.opacity(0.90))
                            Spacer()
                            if currentSlug == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VitaColors.accentLight)
                            }
                        }
                    }
                }

                Section("Minhas disciplinas") {
                    if subjects.isEmpty {
                        Text("Nenhuma disciplina ativa.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.45))
                    } else {
                        ForEach(subjects, id: \.slug) { s in
                            Button {
                                onPick(s.slug)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "folder")
                                        .foregroundStyle(VitaColors.accent)
                                    Text(s.name)
                                        .foregroundStyle(Color.white.opacity(0.90))
                                    Spacer()
                                    if currentSlug == s.slug {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(VitaColors.accentLight)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.04, green: 0.03, blue: 0.02))
            .navigationTitle("Mover pra disciplina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(VitaColors.accentLight)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }
}
