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

struct ContinueSessionDrawer: View {
    let model: ActiveStudySessionsViewModel
    let onResume: (ActiveStudySession) -> Void

    @State private var isExpanded = false
    @State private var showFinishAlert = false
    @State private var pendingFinish: ActiveStudySession?

    private var primary: ActiveStudySession? { model.sessions.first }

    var body: some View {
        if let primary {
            Group {
                if isExpanded {
                    expandedDrawer
                        .frame(width: 320)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topLeading)))
                } else {
                    collapsedDrawer(primary)
                        .frame(width: 220)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                }
            }
            .animation(.easeOut(duration: 0.20), value: isExpanded)
            .accessibilityIdentifier("continueSessionDrawer")
            .onChange(of: model.sessions.count) { _, count in
                if count == 0 {
                    isExpanded = false
                    pendingFinish = nil
                }
            }
            .vitaAlert(
                isPresented: $showFinishAlert,
                title: "Encerrar sessão?",
                message: pendingFinish.map { "O progresso de \($0.title) será encerrado." },
                destructiveLabel: "Encerrar",
                cancelLabel: "Continuar",
                onConfirm: finishPendingSession
            )
        }
    }

    private func collapsedDrawer(_ session: ActiveStudySession) -> some View {
        Button {
            PixioHaptics.tap()
            isExpanded = true
        } label: {
            VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                HStack(spacing: VitaTokens.Spacing.md) {
                    resumeIcon(size: 30)

                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                        Text("Continuar sessão")
                            .font(VitaTypography.labelLarge)
                            .foregroundStyle(VitaColors.textPrimary)
                        Text(progressText(session))
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                            .monospacedDigit()
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold)) // ds-allow: tamanho óptico do SF Symbol
                        .foregroundStyle(VitaColors.accentLight.opacity(0.72))
                }
                .padding(.horizontal, VitaTokens.Spacing.md)
                .frame(height: 48)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continuar sessão, \(session.title), \(progressText(session))")
        .accessibilityHint("Abre suas sessões em andamento")
    }

    private var expandedDrawer: some View {
        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
            VStack(spacing: 0) {
                HStack(spacing: VitaTokens.Spacing.sm) {
                    Text("Sessões em andamento")
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)

                    Spacer()

                    Button {
                        isExpanded = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold)) // ds-allow: tamanho óptico do SF Symbol
                            .foregroundStyle(VitaColors.textWarm.opacity(0.68))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fechar sessões em andamento")
                }
                .padding(.leading, VitaTokens.Spacing.lg)
                .padding(.trailing, VitaTokens.Spacing.sm)
                .frame(height: 44)

                Rectangle()
                    .fill(VitaColors.glassBorder.opacity(0.72))
                    .frame(height: 0.5)

                VStack(spacing: VitaTokens.Spacing.xs) {
                    ForEach(Array(model.sessions.prefix(4))) { session in
                        sessionRow(session)
                    }
                }
                .padding(VitaTokens.Spacing.sm)
            }
        }
    }

    private func sessionRow(_ session: ActiveStudySession) -> some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Button {
                PixioHaptics.tap()
                isExpanded = false
                onResume(session)
            } label: {
                HStack(spacing: VitaTokens.Spacing.md) {
                    resumeIcon(size: 34)

                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                        Text(session.title)
                            .font(VitaTypography.labelLarge)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(VitaColors.textPrimary.opacity(0.08))
                                Capsule()
                                    .fill(VitaColors.accent)
                                    .frame(width: geometry.size.width * progress(session))
                            }
                        }
                        .frame(height: 3)

                        Text(progressText(session))
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                            .monospacedDigit()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resumeSession_\(session.engine.rawValue)_\(session.id)")
            .accessibilityLabel("Continuar \(session.title), \(progressText(session))")

            Button {
                pendingFinish = session
                showFinishAlert = true
            } label: {
                if model.finishingIds.contains(session.id) {
                    ProgressView()
                        .tint(VitaColors.accent)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold)) // ds-allow: tamanho óptico do SF Symbol
                        .foregroundStyle(VitaColors.textWarm.opacity(0.64))
                }
            }
            .buttonStyle(.plain)
            .frame(width: 40, height: 44)
            .disabled(model.finishingIds.contains(session.id))
            .accessibilityLabel("Encerrar \(session.title)")
        }
        .padding(.leading, VitaTokens.Spacing.sm)
        .padding(.trailing, VitaTokens.Spacing.xs)
        .frame(minHeight: 62)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(VitaColors.textPrimary.opacity(0.035))
        )
    }

    private func resumeIcon(size: CGFloat) -> some View {
        Image(systemName: "play.fill")
            .font(.system(size: size * 0.42, weight: .semibold)) // ds-allow: ícone escala com o container
            .foregroundStyle(VitaColors.accentLight)
            .frame(width: size, height: size)
            .background(Circle().fill(VitaColors.accentSubtle))
            .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
    }

    private func progress(_ session: ActiveStudySession) -> CGFloat {
        guard session.total > 0 else { return 0 }
        return min(1, max(0, CGFloat(session.current) / CGFloat(session.total)))
    }

    private func progressText(_ session: ActiveStudySession) -> String {
        let current = min(max(0, session.current), max(0, session.total))
        return "\(current) de \(session.total) · \(kindLabel(session.kind))"
    }

    private func kindLabel(_ kind: ActiveStudySessionKind) -> String {
        switch kind {
        case .questoes: return "Questões"
        case .simulado: return "Simulado"
        case .flashcards: return "Flashcards"
        }
    }

    private func finishPendingSession() {
        guard let session = pendingFinish else { return }
        pendingFinish = nil
        Task {
            await model.finish(session)
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
