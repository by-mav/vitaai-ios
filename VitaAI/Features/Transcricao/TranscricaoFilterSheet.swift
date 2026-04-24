import SwiftUI

/// Sheet pra filtrar a lista de gravações por disciplina. Padrão Apple
/// (Mail / Notes / Files): botão ícone no header abre este sheet com
/// busca + lista alfabética + quick actions.
struct TranscricaoFilterSheet: View {
    let disciplines: [String]
    @Binding var selected: String?

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [String] {
        let sorted = disciplines.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        guard !query.isEmpty else { return sorted }
        return sorted.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selected = nil
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "tray.full")
                                .foregroundStyle(Color.white.opacity(0.55))
                                .frame(width: 20)
                            Text("Todas as gravações")
                                .foregroundStyle(Color.white.opacity(0.90))
                            Spacer()
                            if selected == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VitaColors.accentLight)
                            }
                        }
                    }
                }

                if !filtered.isEmpty {
                    Section("Disciplinas") {
                        ForEach(filtered, id: \.self) { d in
                            Button {
                                selected = d
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "book.closed.fill")
                                        .foregroundStyle(VitaColors.accent)
                                        .frame(width: 20)
                                    Text(d)
                                        .foregroundStyle(Color.white.opacity(0.90))
                                    Spacer()
                                    if selected == d {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(VitaColors.accentLight)
                                    }
                                }
                            }
                        }
                    }
                } else if !query.isEmpty {
                    Section {
                        Text("Nenhuma disciplina encontrada.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.04, green: 0.03, blue: 0.02))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar disciplina")
            .navigationTitle("Filtrar")
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
