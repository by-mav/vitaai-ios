import SwiftUI

// MARK: - CreateWithVitaSheet — "Criar com o Vita" (Importação mágica)
//
// Gaveta com os caminhos de criação assistida (Rafael 2026-07-19; spec
// agent-brain/specs/vitaai/importacao-magica-flashcards.md §4):
// PDF · Gravar aula · Arquivo de áudio · Fotografar anotações · Anki · Colar.
// Cada opção liga num MOTOR que já existe — esta sheet é só o hub. Visual 100%
// Vita gold glass, cards via HubOptionCard (compartilhado com a gaveta do "+").

struct CreateWithVitaSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onPDF: () -> Void
    let onRecordLecture: () -> Void
    let onAudioFile: () -> Void
    let onPhoto: () -> Void
    /// nil = opção Anki ainda não disponível (aparece só quando o import existe).
    var onAnki: (() -> Void)? = nil
    let onPaste: () -> Void

    var body: some View {
        VitaSheet(title: "Criar com o Vita", detents: [.large]) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: VitaTokens.Spacing.md) {
                    HubOptionCard(
                        icon: "doc.text",
                        title: "PDF ou material",
                        subtitle: "Escolha um material teu e o Vita gera os cards",
                        compact: true
                    ) { pick(onPDF) }

                    HubOptionCard(
                        icon: "mic.fill",
                        title: "Gravar aula",
                        subtitle: "Grave a aula e transforme em flashcards",
                        compact: true
                    ) { pick(onRecordLecture) }

                    HubOptionCard(
                        icon: "waveform",
                        title: "Arquivo de áudio",
                        subtitle: "Envie um áudio de aula já gravado",
                        compact: true
                    ) { pick(onAudioFile) }

                    HubOptionCard(
                        icon: "camera.fill",
                        title: "Fotografar anotações",
                        subtitle: "Foto do caderno ou do slide vira cards",
                        compact: true
                    ) { pick(onPhoto) }

                    if let onAnki {
                        HubOptionCard(
                            icon: "square.and.arrow.down.on.square",
                            title: "Importar do Anki",
                            subtitle: "Traga teus baralhos .apkg",
                            compact: true
                        ) { pick(onAnki) }
                    }

                    HubOptionCard(
                        icon: "doc.on.clipboard",
                        title: "Colar suas anotações",
                        subtitle: "Cole um texto e gere flashcards",
                        compact: true
                    ) { pick(onPaste) }
                }
                .padding(.horizontal, VitaTokens.Spacing.xl)
                .padding(.top, VitaTokens.Spacing.sm)
                .padding(.bottom, VitaTokens.Spacing._3xl)
            }
        }
    }

    /// Fecha a gaveta e só então dispara — apresentar sheet com outra viva faz
    /// o UIKit cancelar a apresentação (mesmo padrão da gaveta do "+").
    private func pick(_ action: @escaping () -> Void) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            action()
        }
    }
}

#Preview {
    CreateWithVitaSheet(
        onPDF: {}, onRecordLecture: {}, onAudioFile: {},
        onPhoto: {}, onAnki: {}, onPaste: {}
    )
    .preferredColorScheme(.dark)
}
