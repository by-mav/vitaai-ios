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



// MARK: - VitaCortinaAtividade — o widget flutuante do que está em andamento
//
// Regras (Rafael 2026-07-24). A versão anterior era uma cortina PRESA no topo:
// cobria a topnav e não tinha como tirar da frente. Agora:
//  • FLUTUA onde o aluno quiser — arrasta e a posição fica salva entre telas
//    e entre sessões (começa no canto superior esquerdo);
//  • empurrar pra fora pela lateral RECOLHE num selo pequeno grudado na borda
//    (o botão « no cabeçalho faz o mesmo); tocar no selo abre de volta;
//  • no máximo UM item POR TIPO (questões / flashcards / simulado) — o mais
//    recente de cada, mesma regra do backend ("1 sessão aberta por tipo").
//    Só aparece o que existe: quem tem só questões vê uma linha só.
//
// Vale no app inteiro, não só na Home — foi por isso que o gavetão da Jornada
// nunca resolveu: ficava preso numa aba só.

struct VitaCortinaAtividade: View {
    let sessoes: [ActiveStudySession]
    /// Outras coisas rodando agora (transcricao, Atlas...). Nome + icone.
    var extras: [ItemAtivo] = []
    let onRetomar: (ActiveStudySession) -> Void

    /// Onde o aluno largou o widget (canto superior esquerdo por padrão).
    @AppStorage("cortinaAtividadeX") private var posX: Double = 12
    @AppStorage("cortinaAtividadeY") private var posY: Double = 6
    /// Recolhido = só o selo na borda.
    @AppStorage("cortinaAtividadeRecolhida") private var recolhida = false
    @State private var arrasto: CGSize = .zero
    /// Ligado enquanto o aluno ARRASTA: impede que soltar o dedo em cima de uma
    /// linha dispare "Retomar" sem querer (o arrasto e o toque disputavam).
    @State private var arrastando = false

    struct ItemAtivo: Identifiable {
        let id: String
        let icone: String
        let titulo: String
        let detalhe: String
        let abrir: () -> Void
    }

    private let largura: CGFloat = 244
    private let margem: CGFloat = 8
    /// Quanto precisa empurrar ALÉM da borda pra recolher (evita recolher sem querer).
    private let empurraoParaRecolher: Double = 22

    /// No máximo um por tipo, o mais recente de cada.
    private var sessoesUnicas: [ActiveStudySession] {
        var tipos = Set<ActiveStudySessionKind>()
        return sessoes
            .sorted { $0.updatedAt > $1.updatedAt }
            .filter { tipos.insert($0.kind).inserted }
    }

    private var total: Int { sessoesUnicas.count + extras.count }
    private var larguraSelo: CGFloat { CGFloat(26 + 15 * min(total, 3)) }

    var body: some View {
        if total > 0 {
            GeometryReader { geo in
                flutuante(em: geo.size)
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    /// O widget em si, já posicionado e arrastável dentro da área da tela.
    @ViewBuilder
    private func flutuante(em area: CGSize) -> some View {
        let larg = recolhida ? larguraSelo : largura
        let p = posicao(em: area, largura: larg)
        Group {
            if recolhida { selo } else { painel }
        }
        .frame(width: larg, alignment: .leading)
        .offset(x: p.x, y: p.y)
        // simultaneo + distancia minima: toque continua chegando nos botoes, e
        // so vira arrasto depois de mover de verdade.
        .simultaneousGesture(arrastar(em: area, largura: larg))
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: recolhida)
    }

    /// Mantém o widget dentro da tela mesmo em rotação/tela menor.
    private func posicao(em area: CGSize, largura larg: CGFloat) -> CGPoint {
        let maxX = max(Double(margem), Double(area.width - larg - margem))
        let maxY = max(Double(margem), Double(area.height) - 96)
        return CGPoint(
            x: min(max(Double(margem), posX + Double(arrasto.width)), maxX),
            y: min(max(Double(margem), posY + Double(arrasto.height)), maxY)
        )
    }

    private func arrastar(em area: CGSize, largura larg: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { g in
                arrasto = g.translation
                arrastando = true
            }
            .onEnded { g in
                let bruto = CGPoint(x: posX + Double(g.translation.width),
                                    y: posY + Double(g.translation.height))
                let maxX = max(Double(margem), Double(area.width - larg - margem))
                arrasto = .zero

                if !recolhida,
                   bruto.x < Double(margem) - empurraoParaRecolher
                    || bruto.x > maxX + empurraoParaRecolher {
                    // empurrou pra fora pela lateral → vira selo naquela borda
                    let naDireita = bruto.x > Double(area.width) / 2
                    recolhida = true
                    posX = naDireita
                        ? max(Double(margem), Double(area.width - larguraSelo - margem))
                        : Double(margem)
                } else {
                    posX = min(max(Double(margem), bruto.x), maxX)
                }
                posY = min(max(Double(margem), bruto.y), max(Double(margem), Double(area.height) - 96))
                // solta a trava um instante depois: o Button so dispara ao
                // soltar o dedo, e sem esta folga ele passaria assim mesmo.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { arrastando = false }
            }
    }

    // MARK: painel aberto

    private var painel: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            HStack(spacing: VitaTokens.Spacing.sm) {
                Circle()
                    .fill(VitaColors.accent)
                    .frame(width: 6, height: 6)
                Text("EM ANDAMENTO")
                    .font(VitaTypography.labelSmall)
                    .fontWeight(.semibold)
                    .kerning(0.8)
                    .foregroundStyle(VitaColors.sectionLabel)
                Spacer(minLength: 0)
                Button { if !arrastando { recolhida = true } } label: {
                    Image(systemName: "chevron.compact.left")
                        .font(VitaTypography.labelLarge)
                        .foregroundStyle(VitaColors.accent.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Recolher para o canto")
            }

            VStack(spacing: 0) {
                ForEach(Array(sessoesUnicas.enumerated()), id: \.offset) { idx, s in
                    linha(icone: icone(de: s), titulo: s.title,
                          detalhe: "\(s.current) de \(s.total)") { onRetomar(s) }
                    if idx < total - 1 { divisoria }
                }
                ForEach(Array(extras.enumerated()), id: \.offset) { idx, e in
                    linha(icone: e.icone, titulo: e.titulo, detalhe: e.detalhe, acao: e.abrir)
                    if sessoesUnicas.count + idx < total - 1 { divisoria }
                }
            }

            // pega de arrastar: diz "me leve pra onde quiser"
            Capsule()
                .fill(VitaColors.textWarm.opacity(0.22))
                .frame(width: 34, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(.horizontal, VitaTokens.Spacing.md)
        .padding(.vertical, VitaTokens.Spacing.md)
        .glassCard(cornerRadius: VitaTokens.Radius.lg)
        .transition(.scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity))
    }

    // MARK: selo (estado recolhido)

    private var selo: some View {
        Button {
            if !arrastando { recolhida = false }
        } label: {
            HStack(spacing: 3) {
                ForEach(Array(sessoesUnicas.prefix(3).enumerated()), id: \.offset) { _, s in
                    Image(systemName: icone(de: s))
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.accent)
                }
                if sessoesUnicas.isEmpty {
                    Circle().fill(VitaColors.accent).frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.sm)
            .padding(.vertical, VitaTokens.Spacing.xs)
            .background(Capsule().fill(VitaColors.glassBg))
            .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(total) em andamento. Toque para abrir.")
        .transition(.scale.combined(with: .opacity))
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
        Button { if !arrastando { acao() } } label: {
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
