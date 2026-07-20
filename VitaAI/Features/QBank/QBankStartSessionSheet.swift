import SwiftUI

// MARK: - Tela pré-sessão de Questões
//
// Aberta pelo "Iniciar treino" da página de Questões (Rafael 2026-07-20).
//
// A divisão é: a PÁGINA decide o BOLO (quais questões entram — instituição,
// ano, formato, dificuldade, especialidade); esta TELA decide a SESSÃO (nome,
// quantas, como). Antes tudo estava misturado na mesma página e o aluno
// apertava "Iniciar" sem nunca ver o que ia começar.
//
// Reusa o que já existe — nada de componente novo: `ModePills` (o switcher
// Prática/Simulado, que fica NO TOPO por decisão do Rafael), `VitaGlassCard`,
// `GlassTextField`, `AdvancedToggleItem`. O único bloco novo é a distribuição
// por especialidade, que não existia em lugar nenhum.

struct QBankStartSessionSheet: View {
    let vm: QBankBuilderViewModel
    let onStart: (String, QBankMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var perDiscipline: [String: Int] = [:]

    /// Quantas questões a sessão vai ter de fato: a soma por especialidade
    /// quando o aluno distribuiu, senão a quantidade global.
    private var effectiveCount: Int {
        let soma = perDiscipline.values.reduce(0, +)
        return soma > 0 ? soma : vm.state.questionCount
    }

    private var poolCount: Int { vm.state.displayCount }

    /// Especialidades escolhidas na página. Vazio = o aluno não filtrou, então
    /// não há por que pedir distribuição — a sessão sorteia do bolo inteiro.
    private var selectedDisciplines: [(slug: String, name: String, total: Int)] {
        vm.state.groups.flatMap { group in
            group.children
                .filter { vm.state.selectedSubgroupIds.contains($0.id) }
                .map { (slug: $0.id, name: $0.name, total: $0.count) }
        }
    }

    // Folha, não página (Rafael 2026-07-20). Sem `NavigationStack` e sem fundo
    // próprio: o fundo é o material grafite compartilhado que a apresentação
    // (`studyFilterSheet`) injeta, o mesmo dos cards e das outras folhas. Ela
    // também para abaixo do hero, então o número lá em cima continua à vista.
    var body: some View {
        VStack(spacing: 0) {
            // Cabeçalho da folha, no mesmo formato das outras (título à
            // esquerda, fechar à direita) — nada de barra de navegação.
            HStack(alignment: .firstTextBaseline) {
                header
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

            Divider().background(VitaColors.glassBorder.opacity(0.4))

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
                    titleSection
                    modeSection
                    amountSection
                }
                .padding(.horizontal, VitaTokens.Spacing.lg)
                .padding(.top, VitaTokens.Spacing.md)
                .padding(.bottom, VitaTokens.Spacing.lg)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomCTA }
        .onAppear { if title.isEmpty { title = defaultTitle() } }
    }

    // MARK: - Blocos

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Iniciar treino")
                .font(PixioTypo.title)
                .foregroundStyle(VitaColors.textPrimary)
            Text("Dê um nome, escolha quantas questões e como quer responder.")
                .font(PixioTypo.caption)
                .foregroundStyle(VitaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// O MESMO switcher que já existia na página — movido pra cá, não recriado.
    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("MODO")
            HStack(spacing: 0) {
                ForEach(QBankMode.allCases, id: \.self) { m in
                    let isSelected = vm.state.mode == m
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { vm.setMode(m) }
                    } label: {
                        VStack(spacing: 2) {
                            Text(m.displayName)
                                .font(.system(size: 13, weight: .semibold))  // ds-allow: switcher de modo
                                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                            Text(m == .pratica ? "feedback a cada questão" : "gabarito no final")
                                .font(.system(size: 9))  // ds-allow: switcher de modo
                                .foregroundStyle(isSelected ? VitaColors.accent.opacity(0.7) : VitaColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? VitaColors.accent.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)  // ds-allow: raio concentrico = 14 do card - 4 de padding
                                .stroke(isSelected ? VitaColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))  // ds-allow: raio concentrico = 14 do card - 4 de padding
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassCard(cornerRadius: 14)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NOME DA SESSÃO")
            GlassTextField(placeholder: defaultTitle(), text: $title)
        }
    }

    @ViewBuilder
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("QUANTIDADE")
                Spacer(minLength: VitaTokens.Spacing.sm)
                Text(poolSummary)
                    .font(PixioTypo.micro)
                    .foregroundStyle(VitaColors.textTertiary)
            }

            StudyAmountSliderCard(
                title: "Total da sessão",
                value: min(vm.state.questionCount, maxQuestions),
                range: 1...maxQuestions,
                step: 1,
                theme: .questoes,
                valueSuffix: "questões",
                presets: [10, 20, 30, 50, 100].filter { $0 <= maxQuestions },
                onChange: { novo in
                    vm.setQuestionCount(novo)
                    // Mexeu no total → a distribuição manual perde sentido.
                    perDiscipline.removeAll()
                }
            )

            // Distribuição por especialidade só aparece quando o aluno escolheu
            // mais de uma — com zero ou uma, repartir não significa nada.
            if selectedDisciplines.count > 1 {
                perDisciplineBlock
            }
        }
    }

    private var perDisciplineBlock: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Por especialidade")
                        .font(PixioTypo.sans(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                    Button("Distribuir") { distribuir() }
                        .font(PixioTypo.micro)
                        .foregroundStyle(VitaColors.accent)
                    Button("Zerar") { perDiscipline.removeAll() }
                        .font(PixioTypo.micro)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                ForEach(selectedDisciplines, id: \.slug) { disc in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(disc.name)
                                .font(PixioTypo.sans(size: 13, weight: .medium))
                                .foregroundStyle(VitaColors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(perDiscipline[disc.slug] ?? 0)")
                                .font(PixioTypo.sans(size: 13, weight: .bold))
                                .foregroundStyle(VitaColors.accent)
                                .monospacedDigit()
                            Text("/ \(disc.total)")
                                .font(PixioTypo.micro)
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(perDiscipline[disc.slug] ?? 0) },
                                set: { perDiscipline[disc.slug] = Int($0.rounded()) }
                            ),
                            in: 0...Double(max(disc.total, 1)),
                            step: 1
                        )
                        .tint(VitaColors.accent)
                    }
                }
            }
            .padding(14)
        }
    }

    /// Botao da gaveta. Diferente do da pagina: aqui NAO existe tab bar, entao
    /// nao ha 78pt pra reservar — sem isso o botao subia por cima do conteudo.
    private var bottomCTA: some View {
        VStack(spacing: 6) {
            if vm.state.creatingSession {
                HStack(spacing: 8) {
                    ProgressView().tint(VitaColors.accent)
                    Text("Montando sessão...")
                        .font(PixioTypo.caption)
                        .foregroundStyle(VitaColors.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                StudyShellCTA(
                    title: ctaTitle,
                    theme: .questoes,
                    action: start,
                    systemImage: "play.fill"
                )
                .opacity(poolCount > 0 ? 1.0 : 0.4)
                .disabled(poolCount == 0)
                .padding(.horizontal, VitaTokens.Spacing.lg)
            }
        }
        .padding(.top, VitaTokens.Spacing.md)
        .padding(.bottom, VitaTokens.Spacing.lg)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: VitaColors.surface.opacity(0.92), location: 0.25),
                    .init(color: VitaColors.surface, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    /// Teto fixo em 500 (Rafael 2026-07-20): se o filtro tem menos, a sessao repete
    /// questao — e escolha do aluno, nao motivo pra encolher a barra.
    private var maxQuestions: Int { 500 }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(PixioTypo.sectionLabel)
            .tracking(0.8)
            .foregroundStyle(VitaColors.sectionLabel)
    }

    // MARK: - Lógica

    private var poolSummary: String {
        poolCount > 0 ? "\(formatNumber(poolCount)) questões disponíveis" : "nenhuma questão bate com os filtros"
    }

    private var ctaTitle: String {
        if poolCount == 0 { return "Sem questões disponíveis" }
        return "Começar (\(min(effectiveCount, poolCount)) questões)"
    }

    /// "Sessão 20/07" — mesmo padrão que o aluno já vê no histórico.
    private func defaultTitle() -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
        f.locale = Locale(identifier: "pt_BR")
        return "Sessão \(f.string(from: Date()))"
    }

    /// Reparte o total igualmente entre as especialidades escolhidas, sem
    /// passar do que cada uma tem. A sobra da divisão vai pras primeiras.
    private func distribuir() {
        let discs = selectedDisciplines
        guard !discs.isEmpty else { return }
        let total = vm.state.questionCount
        let base = total / discs.count
        let resto = total % discs.count
        var novo: [String: Int] = [:]
        for (i, d) in discs.enumerated() {
            novo[d.slug] = min(base + (i < resto ? 1 : 0), d.total)
        }
        perDiscipline = novo
    }

    private func start() {
        Task {
            let nome = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if let id = await vm.createSession(title: nome.isEmpty ? nil : nome) {
                dismiss()
                onStart(id, vm.state.mode)
            }
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
