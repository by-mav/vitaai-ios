import SwiftUI

// MARK: - Favoritas
//
// A folha do coração do topo (Rafael 2026-07-20).
//
// No servidor a favorita NÃO é tabela própria: é a lista do aluno com
// kind='favorites'. Por isso esta tela lê `/api/qbank/lists` + o GET das
// questões da lista — o mesmo caminho que qualquer outra lista usaria.
//
// O que ela faz de útil além de mostrar: "Treinar favoritas" monta uma sessão
// só com elas. Era esse o motivo de reaproveitar lista em vez de inventar
// tabela — a sessão já sabia trabalhar com lista.

struct QBankFavoriteList: Decodable, Identifiable {
    let id: Int
    let title: String
    let kind: String?
    let questionCount: Int?
}

struct QBankListsResponse: Decodable {
    let lists: [QBankFavoriteList]
}

struct QBankListQuestion: Decodable, Identifiable {
    let id: Int
    let statement: String
    let year: Int?
    let difficulty: String?
    let institutionName: String?
}

struct QBankListQuestionsResponse: Decodable {
    let questions: [QBankListQuestion]
}

struct QBankFavoritesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container

    @State private var questions: [QBankListQuestion] = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().background(VitaColors.glassBorder.opacity(0.4))

            if loading {
                loadingRow
            } else if questions.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(questions) { q in
                            row(q)
                        }
                    }
                    .padding(.horizontal, VitaTokens.Spacing.lg)
                    .padding(.top, VitaTokens.Spacing.md)
                    .padding(.bottom, VitaTokens.Spacing.lg)
                }
            }

            Spacer(minLength: 0)
        }
        // Sem isto o conteudo curto (estado vazio) fica centralizado na folha e
        // abre com um vazio enorme em cima do titulo — ancora no topo.
        .frame(maxHeight: .infinity, alignment: .top)
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Favoritas")
                    .font(PixioTypo.title)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(questions.isEmpty
                     ? "As questões que você salvar aparecem aqui."
                     : "\(questions.count) \(questions.count == 1 ? "questão salva" : "questões salvas")")
                    .font(PixioTypo.caption)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            Spacer(minLength: VitaTokens.Spacing.sm)
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))  // ds-allow: botão fechar da folha
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.top, VitaTokens.Spacing.lg)
        .padding(.bottom, VitaTokens.Spacing.md)
    }

    private func row(_ q: QBankListQuestion) -> some View {
        VitaGlassCard(cornerRadius: VitaTokens.Radius.md) {
            VStack(alignment: .leading, spacing: 8) {
                Text(q.statement)
                    .font(PixioTypo.sans(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    if let year = q.year {
                        metaChip(icon: "calendar", text: "\(year)")
                    }
                    if let inst = q.institutionName, !inst.isEmpty {
                        metaChip(icon: "building.columns", text: inst)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))  // ds-allow: ícone do chip de meta
            Text(text)
                .font(PixioTypo.micro)
                .lineLimit(1)
        }
        .foregroundStyle(VitaColors.textSecondary)
    }

    /// Vazio de verdade: sem favorita nenhuma, o aluno precisa saber COMO cria
    /// uma — senão a tela é um beco.
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.system(size: 30))  // ds-allow: ícone do estado vazio
                .foregroundStyle(VitaColors.textTertiary)
            Text("Nenhuma questão salva ainda")
                .font(PixioTypo.sans(size: 15, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
            Text("Durante um treino, toque no coração no alto da questão para guardá-la aqui.")
                .font(PixioTypo.caption)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VitaTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitaTokens.Spacing._3xl)
    }

    private var loadingRow: some View {
        HStack(spacing: 10) {
            ProgressView().tint(VitaColors.accent)
            Text("Carregando favoritas…")
                .font(PixioTypo.caption)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitaTokens.Spacing._3xl)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let lists: QBankListsResponse = try await container.api.getQBankLists()
            // A favorita é achada pelo `kind`, não pelo título: o aluno pode
            // renomear a lista e o coração tem que continuar achando.
            guard let fav = lists.lists.first(where: { $0.kind == "favorites" }) else {
                questions = []
                return
            }
            let res: QBankListQuestionsResponse = try await container.api.getQBankListQuestions(listId: fav.id)
            questions = res.questions
        } catch {
            NSLog("[QBankFavorites] falha ao carregar: %@", String(describing: error))
            questions = []
        }
    }
}
