import SwiftUI

// MARK: - Reportar questão
//
// A folha que abre na bandeirinha da questão (Rafael 2026-07-20).
//
// Os motivos NÃO estão escritos aqui: vêm de `GET /api/qbank/report-reasons`.
// Foi pedido explícito — "nada hardcoded". Consequência prática: tirar ou
// acrescentar motivo é UPDATE no banco, não release na App Store. O servidor
// manda até o ícone (SF Symbol) e se aquele motivo exige o texto livre.
//
// Enviar só GUARDA. Quem lê depois é o Pulse.

struct QBankReportReason: Decodable, Identifiable, Hashable {
    let slug: String
    let label: String
    let description: String?
    let icon: String?
    let requiresComment: Bool

    var id: String { slug }
}

struct QBankReportReasonsResponse: Decodable {
    let reasons: [QBankReportReason]
}

struct QBankReportRequest: Encodable {
    let reason: String
    let comment: String?
}

struct QBankOkResponse: Decodable {
    var ok: Bool = false
}

struct QBankFavoriteResponse: Decodable {
    var favorited: Bool = false
}

struct QBankReportSheet: View {
    let questionId: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container

    @State private var reasons: [QBankReportReason] = []
    @State private var loading = true
    @State private var selected: QBankReportReason?
    @State private var comment: String = ""
    @State private var sending = false
    @State private var failure: String?
    @State private var sent = false

    private var needsComment: Bool { selected?.requiresComment == true }
    private var canSend: Bool {
        guard let selected, !sending else { return false }
        if selected.requiresComment {
            return !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().background(VitaColors.glassBorder.opacity(0.4))

            if sent {
                confirmation
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
                        if loading {
                            loadingRow
                        } else if reasons.isEmpty {
                            emptyRow
                        } else {
                            reasonGrid
                            if needsComment { commentField }
                            if let failure { failureRow(failure) }
                        }
                    }
                    .padding(.horizontal, VitaTokens.Spacing.lg)
                    .padding(.top, VitaTokens.Spacing.md)
                    .padding(.bottom, VitaTokens.Spacing.lg)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !sent { sendButton }
        }
        .task { await load() }
    }

    // MARK: - Blocos

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reportar questão")
                    .font(PixioTypo.title)
                    .foregroundStyle(VitaColors.textPrimary)
                Text("Selecione o tipo de problema encontrado.")
                    .font(PixioTypo.caption)
                    .foregroundStyle(VitaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    private var reasonGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(reasons) { reason in
                reasonCard(reason)
            }
        }
    }

    private func reasonCard(_ reason: QBankReportReason) -> some View {
        let isSelected = selected?.slug == reason.slug
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selected = isSelected ? nil : reason
                failure = nil
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: reason.icon ?? "exclamationmark.triangle")
                    .font(.system(size: 16, weight: .semibold))  // ds-allow: ícone do cartão de motivo
                    .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                            .fill((isSelected ? VitaColors.accent : VitaColors.textSecondary).opacity(0.14))
                    )

                Text(reason.label)
                    .font(PixioTypo.sans(size: 14, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .multilineTextAlignment(.leading)

                if let d = reason.description, !d.isEmpty {
                    Text(d)
                        .font(PixioTypo.micro)
                        .foregroundStyle(VitaColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md)
                    .fill(isSelected ? VitaColors.accent.opacity(0.10) : VitaColors.glassBg.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md)
                    .stroke(isSelected ? VitaColors.accent.opacity(0.45) : VitaColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var commentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("O QUE ACONTECEU")
                .font(PixioTypo.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            GlassTextField(placeholder: "Descreva o problema", text: $comment)
        }
    }

    private var loadingRow: some View {
        HStack(spacing: 10) {
            ProgressView().tint(VitaColors.accent)
            Text("Carregando motivos…")
                .font(PixioTypo.caption)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, VitaTokens.Spacing.xl)
    }

    /// Sem motivos = servidor fora do ar ou lista vazia. Não invento opção local:
    /// mostrar botão que não grava seria mentir pro aluno.
    private var emptyRow: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 24))  // ds-allow: ícone de estado vazio
                .foregroundStyle(VitaColors.textTertiary)
            Text("Não deu para carregar os motivos.")
                .font(PixioTypo.caption)
                .foregroundStyle(VitaColors.textSecondary)
            Button("Tentar de novo") { Task { await load() } }
                .font(PixioTypo.caption)
                .foregroundStyle(VitaColors.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitaTokens.Spacing.xl)
    }

    private func failureRow(_ msg: String) -> some View {
        Text(msg)
            .font(PixioTypo.caption)
            .foregroundStyle(VitaColors.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confirmation: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))  // ds-allow: ícone de confirmação
                .foregroundStyle(VitaColors.accent)
            Text("Obrigado!")
                .font(PixioTypo.sans(size: 18, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
            Text("Recebemos seu aviso e vamos revisar esta questão.")
                .font(PixioTypo.caption)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Fechar") { dismiss() }
                .font(PixioTypo.caption)
                .foregroundStyle(VitaColors.accent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitaTokens.Spacing._2xl)
        .padding(.horizontal, VitaTokens.Spacing.lg)
    }

    private var sendButton: some View {
        VStack(spacing: 6) {
            StudyShellCTA(
                title: sending ? "Enviando…" : "Enviar",
                theme: .questoes,
                action: { Task { await send() } },
                systemImage: "paperplane.fill"
            )
            .opacity(canSend ? 1.0 : 0.4)
            .disabled(!canSend)
            .padding(.horizontal, VitaTokens.Spacing.lg)
        }
        .padding(.top, VitaTokens.Spacing.md)
        .padding(.bottom, VitaTokens.Spacing.lg)
        .background(VitaColors.surface)
    }

    // MARK: - Rede

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let res: QBankReportReasonsResponse = try await container.api.getQBankReportReasons()
            reasons = res.reasons
        } catch {
            // Silêncio aqui é proibido no produto: a lista vazia mostra o retry.
            NSLog("[QBankReport] falha ao carregar motivos: %@", String(describing: error))
            reasons = []
        }
    }

    private func send() async {
        guard let selected else { return }
        sending = true
        failure = nil
        defer { sending = false }
        let texto = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await container.api.reportQBankQuestion(
                id: questionId,
                reason: selected.slug,
                comment: texto.isEmpty ? nil : texto
            )
            withAnimation(.easeInOut(duration: 0.2)) { sent = true }
        } catch {
            NSLog("[QBankReport] falha ao enviar: %@", String(describing: error))
            failure = "Não deu para enviar agora. Tente de novo."
        }
    }
}
