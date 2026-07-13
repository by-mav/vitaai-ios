import SwiftUI

// MARK: - DesempenhoScreen
// Boletim de desempenho do aluno (aberto por botao na aba Progresso). Mostra o
// acerto real vindo do /qbank/progress: geral, por dificuldade (amplo, sempre
// tem dado) e "temas pra focar" — SO temas com um minimo de questoes (senao
// virava fraqueza baseada em 1 questao, que nao vale nada). Rafael 2026-07-13.
struct DesempenhoScreen: View {
    var onBack: () -> Void
    @Environment(\.appContainer) private var container
    @Environment(Router.self) private var router

    @State private var qbank: QBankProgressResponse?
    @State private var loading = true

    // Minimo de questoes respondidas pra um tema contar como "fraco".
    private let minAnswered = 3

    private func rateColor(_ r: Double) -> Color {
        r >= 0.7 ? VitaColors.dataGreen : (r >= 0.5 ? VitaColors.dataAmber : VitaColors.dataRed)
    }
    private func diffLabel(_ d: String) -> String {
        switch d { case "easy": return "Fácil"; case "medium": return "Médio"; case "hard": return "Difícil"; default: return d.capitalized }
    }

    private var weakTopics: [QBankProgressByTopic] {
        (qbank?.byTopic ?? [])
            .filter { $0.answered >= minAnswered && $0.accuracy < 0.7 }
            .sorted { $0.accuracy < $1.accuracy }
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                if loading {
                    Spacer(); ProgressView().tint(VitaColors.accent); Spacer()
                } else {
                    content
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            if qbank == nil {
                qbank = try? await container.api.getQBankProgress()
            }
            loading = false
        }
    }

    private var topBar: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))  // ds-allow: back chevron
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 40, height: 40)
            }
            Text("Meu desempenho")
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, VitaTokens.Spacing.md)
        .padding(.top, VitaTokens.Spacing.sm)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VitaTokens.Spacing.xl) {
                overallCard
                if !(qbank?.byDifficulty.isEmpty ?? true) { difficultyCard }
                weakCard
                ctaButton
            }
            .padding(.horizontal, 18)
            .padding(.top, VitaTokens.Spacing.md)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Acerto geral
    private var overallCard: some View {
        let acc = qbank?.normalizedAccuracy ?? 0
        let answered = qbank?.totalAnswered ?? 0
        let correct = qbank?.totalCorrect ?? 0
        return HStack(spacing: VitaTokens.Spacing.xl) {
            ProgressRingView(
                progress: acc, size: 76, strokeWidth: 8,
                trackColor: VitaColors.glassBorder, progressColor: rateColor(acc)
            )
            .overlay(
                Text("\(Int((acc * 100).rounded()))%")
                    .font(.system(size: 19, weight: .bold))  // ds-allow: numero no anel
                    .foregroundStyle(VitaColors.textPrimary)
            )
            VStack(alignment: .leading, spacing: 4) {
                Text("Acerto médio")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                Text("\(answered) respondidas · \(correct) acertos")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .glassCard(cornerRadius: 16)  // ds-allow: tela de desempenho — valor de UI (tokenizar depois)
    }

    // MARK: - Por dificuldade
    private var difficultyCard: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            Text("Por dificuldade")
                .font(VitaTypography.labelLarge)
                .foregroundStyle(VitaColors.textPrimary)
            ForEach(qbank?.byDifficulty ?? []) { d in
                statRow(name: diffLabel(d.difficulty), rate: d.accuracy, correct: d.correct, total: d.answered, wide: 60)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 16)  // ds-allow: tela de desempenho — valor de UI (tokenizar depois)
    }

    // MARK: - Temas pra focar
    private var weakCard: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            Text("Temas pra focar")
                .font(VitaTypography.labelLarge)
                .foregroundStyle(VitaColors.textPrimary)
            if weakTopics.isEmpty {
                HStack(spacing: VitaTokens.Spacing.md) {
                    Image(systemName: "target")
                        .font(.system(size: 20))  // ds-allow: icone empty state
                        .foregroundStyle(VitaColors.accent)
                    Text("Responda mais questões pra descobrir onde você está fraco (mínimo \(minAnswered) por tema).")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, VitaTokens.Spacing.xs)
            } else {
                ForEach(weakTopics.prefix(6)) { t in
                    statRow(name: t.topicTitle, rate: t.accuracy, correct: t.correct, total: t.answered, wide: 130)
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 16)  // ds-allow: tela de desempenho — valor de UI (tokenizar depois)
    }

    // Linha reutilizavel: nome + barra + fracao, cor por acerto.
    private func statRow(name: String, rate: Double, correct: Int, total: Int, wide: CGFloat) -> some View {
        let col = rateColor(rate)
        return HStack(spacing: VitaTokens.Spacing.md) {
            Text(name)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
                .frame(width: wide, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(VitaColors.glassBorder)
                    Capsule().fill(col).frame(width: max(4, geo.size.width * CGFloat(rate)))
                }
            }
            .frame(height: 6)
            Text("\(correct)/\(total)")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(col)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var ctaButton: some View {
        Button {
            router.navigate(to: .qbank)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle").font(.system(size: 14, weight: .semibold))  // ds-allow: icone cta
                Text("Praticar questões").font(VitaTypography.labelLarge)
            }
            .foregroundStyle(VitaColors.surface)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(VitaColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14))  // ds-allow: tela de desempenho — valor de UI (tokenizar depois)
        }
    }
}
