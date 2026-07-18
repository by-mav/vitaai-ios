import SwiftUI

// MARK: - Dados do ponto de controle
//
// Resumo intermediário mostrado a cada 10 cartas (Rafael 2026-07-17). Derivado do
// histórico de respostas da sessão pelo FlashcardViewModel.
struct FlashcardCheckpointData: Equatable {
    let gradePercent: Int
    let again: Int
    let hard: Int
    let good: Int
    let easy: Int
    let elapsedSeconds: Int
    let cardsStudied: Int
    let totalCards: Int
    let estimatedRemainingSeconds: Int
}

// MARK: - Ponto de controle "Progresso da sessão"
//
// A cada 10 cartas a sessão pausa e mostra este resumo: nota da leva, distribuição
// das respostas, tempo e estimativa. "Mais 10 cartas" continua. Visual Vita gold —
// a referência azul do Rafael foi só pra a ideia. Desligável nos ajustes.
struct FlashcardCheckpointView: View {
    let data: FlashcardCheckpointData
    var onContinue: () -> Void
    var onStats: () -> Void

    // Count-up da nota (mesmo padrão do resumo de fim de sessão).
    @State private var displayedGrade: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(VitaColors.glassBorder).padding(.top, 20)

            gradeBlock
                .padding(.top, 24)

            ratingBreakdown
                .padding(.top, 20)

            Divider().overlay(VitaColors.glassBorder).padding(.top, 20)

            infoRows
                .padding(.top, 4)

            actionButtons
                .padding(.top, 24)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VitaColors.surfaceElevated, in: RoundedRectangle(cornerRadius: VitaTokens.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.xl)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
                displayedGrade = Double(data.gradePercent)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("PONTO DE CONTROLE")
                .font(.system(size: 12, weight: .semibold))
                .kerning(1.4)
                .foregroundStyle(VitaColors.sectionLabel)
            Text("Progresso da sessão")
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Nota + barra de distribuição

    private var gradeBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(Int(displayedGrade.rounded()))")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(VitaColors.accent)
                    .monospacedDigit()
                Text("% NOTA")
                    .font(.system(size: 14, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(VitaColors.accent.opacity(0.85))
            }
            distributionBar
        }
    }

    /// Barra segmentada: a fração estudada é preenchida por cor de resposta
    /// (proporcional às contagens); o resto fica cinza (ainda por estudar).
    private var distributionBar: some View {
        GeometryReader { geo in
            let total = max(data.totalCards, 1)
            let w = geo.size.width
            // MESMAS cores dos botões Erro/Difícil/Bom/Fácil (Rafael 2026-07-17).
            let seg: [(Int, Color)] = [
                (data.again, VitaColors.dataRed),
                (data.hard, VitaColors.dataAmber),
                (data.good, VitaColors.accentHover),
                (data.easy, VitaColors.dataGreen),
            ]
            HStack(spacing: 0) {
                ForEach(Array(seg.enumerated()), id: \.offset) { _, s in
                    if s.0 > 0 {
                        Rectangle()
                            .fill(s.1)
                            .frame(width: w * CGFloat(s.0) / CGFloat(total))
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(height: 10)
            .background(VitaColors.surfaceCard)
            .clipShape(Capsule())
        }
        .frame(height: 10)
    }

    // MARK: Distribuição das respostas

    private var ratingBreakdown: some View {
        HStack(spacing: 0) {
            ratingCell("Erro", data.again, VitaColors.dataRed)
            ratingCell("Difícil", data.hard, VitaColors.dataAmber)
            ratingCell("Bom", data.good, VitaColors.accentHover)
            ratingCell("Fácil", data.easy, VitaColors.dataGreen)
        }
    }

    private func ratingCell(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text("\(count)")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Linhas de info

    private var infoRows: some View {
        VStack(spacing: 0) {
            infoRow("Tempo de estudo", formattedDuration(data.elapsedSeconds))
            Divider().overlay(VitaColors.glassBorder)
            infoRow("Cartas únicas estudadas", "\(data.cardsStudied) / \(data.totalCards)")
            Divider().overlay(VitaColors.glassBorder)
            infoRow("Estim. de tempo restante", formattedDuration(data.estimatedRemainingSeconds))
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
            Spacer()
            Text(value)
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.accent)
                .monospacedDigit()
        }
        .padding(.vertical, 16)
    }

    // MARK: Botões

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: onStats) {
                Text("Estatísticas")
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .glassCard(cornerRadius: 14)
            }
            .buttonStyle(.plain)

            Button(action: onContinue) {
                Text("Mais 10 cartas")
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.surface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(VitaColors.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    private func formattedDuration(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        if m == 0 { return "\(s)s" }
        return "\(m)min \(String(format: "%02d", s))s"
    }
}

#Preview {
    FlashcardCheckpointView(
        data: FlashcardCheckpointData(
            gradePercent: 46, again: 1, hard: 4, good: 5, easy: 0,
            elapsedSeconds: 32, cardsStudied: 10, totalCards: 41,
            estimatedRemainingSeconds: 160
        ),
        onContinue: {}, onStats: {}
    )
    .padding(.vertical, 60)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
