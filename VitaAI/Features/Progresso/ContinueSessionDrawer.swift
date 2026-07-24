import Observation
import SwiftUI

@MainActor
@Observable
final class ActiveStudySessionsViewModel {
    private let api: VitaAPI

    private(set) var sessions: [ActiveStudySession] = []
    private(set) var finishingIds: Set<String> = []
    private(set) var errorMessage: String?

    init(api: VitaAPI) {
        self.api = api
    }

    func refresh() async {
        do {
            sessions = try await api.getActiveStudySessions().sessions
            errorMessage = nil
        } catch {
            errorMessage = "Não foi possível carregar suas sessões."
            NSLog("[ActiveStudySessions] refresh failed: %@", String(describing: error))
        }
    }

    func finish(_ session: ActiveStudySession) async {
        guard !finishingIds.contains(session.id) else { return }
        finishingIds.insert(session.id)
        defer { finishingIds.remove(session.id) }

        do {
            switch session.engine {
            case .qbank:
                _ = try await api.finishQBankSession(id: session.id)
            case .simulado:
                _ = try await api.finishSimulado(attemptId: session.id, timeTakenMs: 0)
            case .flashcards:
                _ = try await api.finishFlashcardStudySession(id: session.id)
            }
            sessions.removeAll { $0.id == session.id && $0.engine == session.engine }
            errorMessage = nil
        } catch {
            errorMessage = "Não foi possível encerrar a sessão."
            NSLog("[ActiveStudySessions] finish failed: %@", String(describing: error))
        }
    }
}



// MARK: - VitaCortinaAtividade — a "notificacao" que desce do topo
//
// Aparece SO quando ha algo em andamento. Toque na cortina (ou arraste pra
// cima) e ela encolhe ate virar um puxador fino grudado no topo; toque no
// puxador (ou arraste pra baixo) e ela volta.
//
// Vale no app inteiro, nao so na Home — foi por isso que o gavetao da Jornada
// nunca resolveu: ficava preso numa aba so.

struct VitaCortinaAtividade: View {
    let sessoes: [ActiveStudySession]
    /// Outras coisas rodando agora (transcricao, Atlas...). Nome + icone.
    var extras: [ItemAtivo] = []
    let onRetomar: (ActiveStudySession) -> Void

    /// Persistido: se o aluno escondeu, fica escondido entre telas.
    @AppStorage("cortinaAtividadeEscondida") private var escondida = false
    @State private var arrasto: CGFloat = 0

    struct ItemAtivo: Identifiable {
        let id: String
        let icone: String
        let titulo: String
        let detalhe: String
        let abrir: () -> Void
    }

    private var total: Int { sessoes.count + extras.count }

    var body: some View {
        if total > 0 {
            VStack(spacing: 0) {
                if escondida { puxador } else { cortina }
            }
            .animation(.easeOut(duration: 0.28), value: escondida)
        }
    }

    // MARK: cortina aberta

    private var cortina: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            HStack(spacing: VitaTokens.Spacing.sm) {
                Circle()
                    .fill(VitaColors.accent)
                    .frame(width: 6, height: 6)
                Text("EM ANDAMENTO")
                    .font(VitaTypography.labelSmall)
                    .fontWeight(.semibold)
                    .kerning(0.8)
                    .foregroundStyle(VitaColors.sectionLabel)
                Spacer()
                Text("\(total)")
                    .font(VitaTypography.labelSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.accent)
            }

            VStack(spacing: 0) {
                ForEach(Array(sessoes.enumerated()), id: \.offset) { idx, s in
                    linha(icone: icone(de: s), titulo: s.title,
                          detalhe: "\(s.current) de \(s.total)") { onRetomar(s) }
                    if idx < total - 1 { divisoria }
                }
                ForEach(Array(extras.enumerated()), id: \.offset) { idx, e in
                    linha(icone: e.icone, titulo: e.titulo, detalhe: e.detalhe, acao: e.abrir)
                    if sessoes.count + idx < total - 1 { divisoria }
                }
            }

            // puxador de fechar: o jeito de "apertar pra esconder"
            Button {
                escondida = true
            } label: {
                Capsule()
                    .fill(VitaColors.textWarm.opacity(0.22))
                    .frame(width: 38, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, VitaTokens.Spacing.xs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Esconder atividades")
        }
        .padding(VitaTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: VitaTokens.Radius.lg)
        .offset(y: min(arrasto, 0))
        .gesture(
            DragGesture()
                .onChanged { g in if g.translation.height < 0 { arrasto = g.translation.height } }
                .onEnded { g in
                    if g.translation.height < -28 { escondida = true }
                    arrasto = 0
                }
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: puxador (estado escondido)

    private var puxador: some View {
        Button {
            escondida = false
        } label: {
            HStack(spacing: VitaTokens.Spacing.xs) {
                Circle().fill(VitaColors.accent).frame(width: 5, height: 5)
                Text("\(total) em andamento")
                    .font(VitaTypography.labelSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.accent)
                Image(systemName: "chevron.down")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.accent.opacity(0.7))
            }
            .padding(.horizontal, VitaTokens.Spacing.md)
            .padding(.vertical, VitaTokens.Spacing.xs)
            .background(Capsule().fill(VitaColors.glassBg))
            .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mostrar o que está em andamento")
        .gesture(
            DragGesture().onEnded { g in if g.translation.height > 20 { escondida = false } }
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: pecinhas

    private var divisoria: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 40)
    }

    private func linha(icone: String, titulo: String, detalhe: String,
                       acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: icone)
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                            .fill(VitaColors.accent.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(titulo)
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text(detalhe)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                Spacer(minLength: 0)
                Text("Retomar")
                    .font(VitaTypography.labelSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.accent)
            }
            .padding(.vertical, VitaTokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func icone(de s: ActiveStudySession) -> String {
        switch s.kind {
        case .flashcards: return "rectangle.on.rectangle.angled"
        case .simulado:   return "list.clipboard"
        default:          return "checkmark.square"
        }
    }
}
