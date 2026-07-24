import SwiftUI

// MARK: - Coração da questão (Rafael 2026-07-20)
//
// Favoritar NÃO tem tabela própria no servidor: é a lista do aluno com
// kind='favorites', criada sozinha no primeiro coração. Consequência boa: a
// favorita já entra em tudo que lê lista — inclusive montar sessão só com elas.
//
// A tela obedece a RESPOSTA do servidor, nunca o que o dedo achou que aconteceu:
// o toque pinta na hora (senão parece travado), mas se a chamada falhar o
// coração VOLTA. Mentir que salvou é pior que demorar.

struct QBankFavoriteButton: View {
    let questionId: Int
    var initiallyFavorited: Bool = false
    /// Avisa o estado FINAL (ja confirmado pelo servidor). Quem mostra o aviso
    /// e a tela — o botao nao conhece toast, so o fato.
    var onChange: ((Bool) -> Void)? = nil

    @Environment(\.appContainer) private var container

    @State private var favorited: Bool = false
    @State private var busy = false
    @State private var pulse = false

    var body: some View {
        Button(action: toggle) {
            Image(systemName: favorited ? "heart.fill" : "heart")
                .font(.system(size: 17, weight: .semibold))  // ds-allow: ícone do coração, par do chevron do header
                .foregroundStyle(favorited ? VitaColors.danger : VitaColors.textSecondary)
                .scaleEffect(pulse ? 1.18 : 1.0)
                .frame(width: 40, height: 40)
                .background(Circle().fill(VitaColors.glassBg.opacity(0.82)))
                .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(favorited ? "Remover dos favoritos" : "Favoritar questão")
        .onAppear { favorited = initiallyFavorited }
    }

    private func toggle() {
        guard !busy else { return }
        let anterior = favorited
        busy = true

        // Pinta na hora — e desfaz se o servidor recusar.
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            favorited.toggle()
            pulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.18)) { pulse = false }
        }

        Task { @MainActor in
            defer { busy = false }
            do {
                let res = try await container.api.toggleQBankQuestionFavorite(id: questionId)
                withAnimation(.easeInOut(duration: 0.15)) { favorited = res.favorited }
                onChange?(res.favorited)
            } catch {
                NSLog("[QBank] favorite(%d) error: %@", questionId, String(describing: error))
                withAnimation(.easeInOut(duration: 0.15)) { favorited = anterior }
            }
        }
    }
}

// MARK: - Bandeirinha de reportar
//
// Abre a folha com os motivos que VÊM DO SERVIDOR (nada hardcoded).

struct QBankReportButton: View {
    let questionId: Int

    @State private var showSheet = false

    var body: some View {
        Button { showSheet = true } label: {
            Image(systemName: "flag")
                .font(.system(size: 16, weight: .semibold))  // ds-allow: ícone da bandeira, par do coração
                .foregroundStyle(VitaColors.textSecondary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(VitaColors.glassBg.opacity(0.82)))
                .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reportar problema nesta questão")
        .sheet(isPresented: $showSheet) {
            QBankReportSheet(questionId: questionId)
                .studyFilterSheet()
        }
    }
}
