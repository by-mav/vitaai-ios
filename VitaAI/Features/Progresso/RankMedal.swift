import SwiftUI

// MARK: - Medalhas de rank (Progresso) — Rafael 2026-07-16
//
// Uma medalha por EIXO de esforço (Questões, Sequência, Simulados, Flashcards…).
// Cada medalha evolui por marcos: 5 ranks (bronze → prata → ouro → platina →
// diamante); os 4 primeiros têm 3 divisões (III → II → I), diamante é único no
// topo = 13 degraus. O tier vem do CONTADOR acumulado (lifetime) daquele eixo.
//
// Fase 1 (esta): escada + contador no cliente, dados que a API já dá. Fase 2:
// mover a escada pro backend (DOME) + eixo "Missões cumpridas".

enum RankTier: Int, CaseIterable {
    case bronze, silver, gold, platinum, diamond

    var name: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Prata"
        case .gold: return "Ouro"
        case .platinum: return "Platina"
        case .diamond: return "Diamante"
        }
    }

    /// Divisões (III/II/I) nos 4 primeiros; diamante é único.
    var hasDivisions: Bool { self != .diamond }

    /// Cores do metal (arte gamificada — fora do token gold do app, é vitrine).
    var bright: Color {
        switch self {
        case .bronze: return Color(red: 0.85, green: 0.60, blue: 0.37)   // ds-allow: metal de medalha (rank)
        case .silver: return Color(red: 0.90, green: 0.92, blue: 0.95)   // ds-allow: metal de medalha (rank)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.30)      // ds-allow: metal de medalha (rank)
        case .platinum: return Color(red: 0.55, green: 0.90, blue: 0.84) // ds-allow: metal de medalha (rank)
        case .diamond: return Color(red: 0.55, green: 0.72, blue: 1.0)   // ds-allow: metal de medalha (rank)
        }
    }
    var deep: Color {
        switch self {
        case .bronze: return Color(red: 0.56, green: 0.35, blue: 0.17)   // ds-allow: metal de medalha (rank)
        case .silver: return Color(red: 0.56, green: 0.58, blue: 0.62)   // ds-allow: metal de medalha (rank)
        case .gold: return Color(red: 0.78, green: 0.58, blue: 0.12)     // ds-allow: metal de medalha (rank)
        case .platinum: return Color(red: 0.20, green: 0.55, blue: 0.50) // ds-allow: metal de medalha (rank)
        case .diamond: return Color(red: 0.22, green: 0.42, blue: 0.78)  // ds-allow: metal de medalha (rank)
        }
    }
    /// Cor legível do texto do rank (sobre o fundo escuro do card).
    var label: Color { bright }
}

/// Estado calculado de uma medalha: em que degrau está e quanto falta.
struct RankState {
    let tier: RankTier
    /// 3, 2 ou 1 (nos ranks com divisão); 0 no diamante.
    let division: Int
    let current: Int
    /// Meta do próximo degrau (nil = topo do diamante, já maximizou o marco visível).
    let next: Int?
    let previous: Int
    let locked: Bool

    /// "Prata II" · "Diamante" · "Bloqueada".
    var title: String {
        if locked { return "Bloqueada" }
        guard tier.hasDivisions, division > 0 else { return tier.name }
        let roman = ["", "I", "II", "III"][min(max(division, 1), 3)]
        return "\(tier.name) \(roman)"
    }

    /// 0…1 dentro do degrau atual (pro anel de progresso).
    var fraction: Double {
        guard let next, next > previous else { return 1 }
        return min(1, max(0, Double(current - previous) / Double(next - previous)))
    }

    /// "31/50" · "no topo".
    var progressText: String {
        guard let next else { return "no topo" }
        return "\(current)/\(next)"
    }
}

/// Escada de 13 marcos de um eixo → mapeia um contador em RankState.
struct RankLadder {
    /// 13 metas crescentes: bronzeIII, bronzeII, bronzeI, prataIII … diamante.
    let thresholds: [Int]

    init(_ thresholds: [Int]) {
        // Sempre 13 degraus (4 ranks × 3 + diamante). Preenche/corta pra 13.
        self.thresholds = thresholds
    }

    func state(count: Int) -> RankState {
        // Quantos marcos já foram batidos.
        let reached = thresholds.filter { count >= $0 }.count  // 0…13
        if reached == 0 {
            return RankState(
                tier: .bronze, division: 3, current: count,
                next: thresholds.first, previous: 0, locked: count == 0
            )
        }
        let idx = min(reached, thresholds.count - 1)          // degrau atingido (0-based no próximo)
        let stepIndex = reached                                // 1…13
        let tierIdx = min((stepIndex - 1) / 3, RankTier.diamond.rawValue)
        let tier = RankTier(rawValue: tierIdx) ?? .diamond
        let division = tier.hasDivisions ? 3 - ((stepIndex - 1) % 3) : 0
        let previous = thresholds[reached - 1]
        let next: Int? = reached < thresholds.count ? thresholds[idx] : nil
        return RankState(
            tier: tier, division: division, current: count,
            next: next, previous: previous, locked: false
        )
    }
}

// MARK: - Catálogo de eixos (Fase 1 — cliente)

struct RankAxis: Identifiable {
    let id: String
    let title: String
    let icon: String          // SF Symbol
    let ladder: RankLadder
}

enum RankAxes {
    static let questions = RankAxis(
        id: "questions", title: "Questões", icon: "checklist",
        ladder: RankLadder([10, 30, 60, 100, 175, 300, 500, 800, 1200, 2000, 3500, 6000, 10000])
    )
    static let streak = RankAxis(
        id: "streak", title: "Sequência", icon: "flame.fill",
        ladder: RankLadder([3, 7, 14, 21, 30, 45, 60, 90, 120, 180, 270, 365, 500])
    )
    static let simulados = RankAxis(
        id: "simulados", title: "Simulados", icon: "stopwatch.fill",
        ladder: RankLadder([1, 3, 6, 10, 15, 25, 40, 60, 90, 130, 180, 250, 365])
    )
    static let flashcards = RankAxis(
        id: "flashcards", title: "Flashcards", icon: "rectangle.stack.fill",
        ladder: RankLadder([50, 150, 300, 600, 1000, 1800, 3000, 5000, 8000, 13000, 20000, 32000, 50000])
    )
}

// MARK: - RankMedalView — a medalha na vitrine (Progresso)
//
// Estética Quadro de Mundo (DESIGN.md §5): emblema circular em RELEVO — metal do
// tier sob luz de cima-esquerda (gradiente + highlight especular + aro + sombra),
// anel de progresso pro próximo degrau. Bloqueada = apagada com cadeado.

struct RankMedalView: View {
    let axis: RankAxis
    let count: Int

    private var state: RankState { axis.ladder.state(count: count) }

    var body: some View {
        HStack(spacing: 11) {
            emblem
            VStack(alignment: .leading, spacing: 3) {
                Text(axis.title)
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(state.locked ? "Bloqueada" : "\(state.title) · \(state.progressText)")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(state.locked ? VitaColors.textTertiary : state.tier.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: vitrine de medalha (mundo)
                .fill(VitaColors.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: vitrine de medalha (mundo)
                        .stroke(state.locked ? VitaColors.surfaceBorder : state.tier.deep.opacity(0.55), lineWidth: 1)
                )
        )
    }

    private var emblem: some View {
        ZStack {
            // Anel de progresso pro próximo degrau (atrás do disco).
            if !state.locked, state.next != nil {
                Circle()
                    .trim(from: 0, to: state.fraction)
                    .stroke(state.tier.bright.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 46, height: 46)
            }
            // Disco de metal em relevo.
            Circle()
                .fill(
                    state.locked
                        ? LinearGradient(
                            colors: [VitaColors.surface, VitaColors.surfaceElevated],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(
                            colors: [state.tier.bright, state.tier.deep],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(.black.opacity(0.28), lineWidth: 1))
                .overlay(
                    // highlight especular (luz de cima na peça de metal)
                    Circle().trim(from: 0.55, to: 0.95)
                        .stroke(.white.opacity(state.locked ? 0 : 0.5), lineWidth: 1.6)
                        .frame(width: 30, height: 30).blur(radius: 0.4)
                )
                .shadow(color: state.locked ? .clear : state.tier.deep.opacity(0.5), radius: 5, y: 1)
            Image(systemName: state.locked ? "lock.fill" : axis.icon)
                .font(.system(size: 15, weight: .bold))  // ds-allow: ícone dentro da medalha (mundo)
                .foregroundStyle(state.locked ? VitaColors.textTertiary : state.tier.deep)
        }
        .frame(width: 46, height: 46)
    }
}

