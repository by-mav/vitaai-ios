import OSLog
import SwiftUI

/// Falha silenciosa aqui ja custou caro: a amostra da Biblioteca sumia sem
/// explicacao quando o servidor devolvia 404. Erro agora vai pro log.
private let deckLog = Logger(subsystem: "com.bymav.vitaai", category: "Flashcards")

// MARK: - DeckHomeScreen — tela CENTRAL do baralho (Rafael 2026-07-19)
//
// TODO baralho abre aqui — os do aluno E as disciplinas da Biblioteca. É a
// visão de PERFORMANCE do aluno naquele baralho + as opções dele. Ref do
// concorrente: 3-tela-central-baralho.png; visual 100% Vita gold glass.
// Spec: agent-brain/specs/vitaai/importacao-magica-flashcards.md §3.
//
// Composição (de cima pra baixo):
//   topo    voltar · busca · compartilhar · config · "+" (CardEditorScreen pronto)
//   título  + "X de N cartões estudados"
//   medidor "Cartas para estudar hoje" + Novas / Para revisar
//   CTA     Estudar
//   nota    % + distribuição Novamente/Difícil/Bom/Fácil (FSRS local)
//   offline baixar / baixado + remover (só disciplina da Biblioteca)
//
// Os números vêm do `LocalFlashcardStore` (FSRS no device) — a mesma fonte que
// agenda a fila. Nada é estimado: card sem review nenhum conta como "novo".

struct DeckHomeScreen: View {
    @Environment(\.appContainer) private var container

    let deckId: String
    var deckTitle: String? = nil
    /// Disciplina da Biblioteca (ex "anatomia") quando o baralho é curado —
    /// habilita o download offline e faz os cards virem do pack/bundle.
    var librarySlug: String? = nil
    /// Quantos cards a disciplina tem no servidor — a tela sabe o tamanho ANTES
    /// de baixar (sem isso um baralho não baixado pareceria vazio).
    var libraryTotalCards: Int = 0
    let onBack: () -> Void
    let onStudy: (String) -> Void

    @State private var deck: FlashcardDeckEntry?
    @State private var summary = LocalFlashcardStore.DeckSummary()
    @State private var loading = true
    @State private var showAddCard = false
    @State private var showBrowser = false
    @State private var showSettings = false
    @State private var showShare = false
    @State private var sharePack: URL?
    @State private var preparingShare = false
    @State private var downloads = DeckDownloadManager.shared
    @State private var confirmRemove = false
    /// Preenchimento da barra de respostas (0→1 ao abrir).
    @State private var barFill: CGFloat = 0
    /// Teto de cartas novas por dia do ALUNO (gaveta de ajustes, salvo no
    /// servidor). O servidor ja respeita esse valor ao montar a fila; era só a
    /// tela que trazia 20 fixo e mentia pra quem tinha configurado outro numero.
    @State private var newPerDay = 20
    /// Amostra do baralho da Biblioteca AINDA NAO baixado. Sem ela a tela nao
    /// mostrava nada e o aluno tinha que baixar as cegas pra saber o que tem
    /// dentro (Rafael 2026-07-21).
    @State private var amostra: LibraryDeckSample?
    @State private var amostraFalhou = false

    private var isLibrary: Bool { librarySlug != nil }
    private var totalCards: Int {
        if summary.total > 0 { return summary.total }
        if isLibrary { return libraryTotalCards }
        return deck?.cardCount ?? 0
    }
    /// Biblioteca ainda não baixada: os cards existem, só não estão aqui.
    private var needsDownload: Bool {
        guard let slug = librarySlug else { return false }
        return !downloads.isDownloaded(slug)
    }
    private var title: String { deck?.title ?? deckTitle ?? "Baralho" }

    var body: some View {
        VStack(spacing: 0) {
            VitaScreenHeader(title: title, onBack: onBack) {
                // A lupa saiu daqui: com quatro botoes o titulo do baralho nao
                // cabia e virava "Farmacolo...". Procurar card e acao do CONTEUDO,
                // entao mora no card de estudo. Rafael 2026-07-21.
                HStack(spacing: VitaTokens.Spacing.xs) {
                    barButton(icon: preparingShare ? "ellipsis" : "square.and.arrow.up") { share() }
                        .disabled(preparingShare)
                    barButton(icon: "gearshape") { showSettings = true }
                    barButton(icon: "plus", prominent: true) { showAddCard = true }
                }
            }
            .padding(.bottom, VitaTokens.Spacing.xs)

            if loading {
                Spacer()
                ProgressView().tint(VitaColors.accent)
                Spacer()
            } else if needsDownload {
                // Baralho da Biblioteca ainda nao baixado NAO e a tela de estudo
                // com os numeros zerados: medidor em 0 e "0% NOTA" nao dizem
                // nada a quem nem baixou. Aqui a tela apresenta a colecao.
                // Rafael 2026-07-21.
                vitrine
            } else if totalCards == 0, !isLibrary {
                emptyState
            } else {
                content
            }
        }
        .navigationBarHidden(true)
        .task {
            await load()
            withAnimation(.easeOut(duration: 0.9)) { barFill = 1 }
        }
        .sheet(isPresented: $showAddCard, onDismiss: { Task { await load() } }) {
            CardEditorScreen(onCreated: { Task { await load() } }, presetDeckTitle: title)
        }
        .sheet(isPresented: $showBrowser) {
            // disciplineSlug e OBRIGATORIO pro baralho da Biblioteca: sem ele o
            // browser acha que o deck e do servidor, busca online, nao encontra
            // (os cards vivem no pack BAIXADO) e mostra lista vazia.
            CardBrowserScreen(
                deckId: deckId,
                deckTitle: title,
                subjectId: deck?.subjectId,
                disciplineSlug: librarySlug
            )
        }
        .sheet(isPresented: $showSettings) {
            FlashcardSettingsV2Sheet()
        }
        // vita-modals-ignore: share sheet é UI de sistema
        .sheet(isPresented: $showShare) {
            if let sharePack {
                VitaShareSheet(items: [sharePack])
            }
        }
        .alert("Remover do aparelho?", isPresented: $confirmRemove) {
            Button("Cancelar", role: .cancel) {}
            Button("Remover", role: .destructive) {
                if let slug = librarySlug {
                    Task { await downloads.remove(slug: slug); await load() }
                }
            }
        } message: {
            Text("Os cartões saem do aparelho e voltam a precisar de internet. Teu progresso é mantido.")
        }
        .trackScreen("DeckHome")
    }

    // MARK: - Estados

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VitaEmptyState(
                title: "Vamos começar adicionando alguns cartões",
                message: "Crie frente e verso do seu jeito — ou gere com o Vita a partir do seu material.",
                actionText: "Adicionar cartões",
                onAction: { showAddCard = true }
            )
            Spacer()
        }
        .padding(.horizontal, VitaTokens.Spacing.xl)
    }

    /// Apresentacao da colecao ANTES do download: quem fez, o que tem dentro e
    /// como sao as cartas. Sem medidor e sem nota — nao ha o que medir ainda.
    private var vitrine: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
                cabecalhoColecao
                primaryCTA
                amostraSection
                Spacer(minLength: VitaTokens.Spacing.xl)
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.top, VitaTokens.Spacing.sm)
        }
    }

    private var cabecalhoColecao: some View {
        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
                HStack(spacing: VitaTokens.Spacing.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .semibold))  // ds-allow: ícone do selo de curadoria
                        .foregroundStyle(VitaColors.accent)
                    Text("Criado por Vita")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.accent)
                }

                Text(title)
                    .font(VitaTypography.headlineSmall)
                    .foregroundStyle(VitaColors.textPrimary)

                Text("Coleção curada pela equipe do Vita. Baixe uma vez e estude offline, com repetição espaçada.")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: VitaTokens.Spacing.md) {
                    fatoDaColecao(valor: "\(totalCards)", rotulo: totalCards == 1 ? "carta" : "cartas")
                    if let amostra, amostra.cards.contains(where: { ($0.cardType ?? "") == "cloze" }) {
                        fatoDaColecao(valor: "Lacuna", rotulo: "e frente/verso")
                    }
                    fatoDaColecao(valor: "Offline", rotulo: "depois de baixar")
                }
            }
            .padding(VitaTokens.Spacing.lg)
        }
    }

    private func fatoDaColecao(valor: String, rotulo: String) -> some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(VitaTypography.labelLarge)
                .foregroundStyle(VitaColors.textPrimary)
                .monospacedDigit()
            Text(rotulo)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitaTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(VitaColors.surfaceCard.opacity(0.5))
        )
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
                Text("\(summary.studied) de \(totalCards) cartões estudados")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)

                todayCard
                primaryCTA
                amostraSection
                scoreCard

                if !isLibrary {
                    Button { showAddCard = true } label: {
                    HStack(spacing: VitaTokens.Spacing.sm) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))  // ds-allow: ícone do botão secundário
                        Text("Adicionar cartões")
                            .font(VitaTypography.labelMedium)
                    }
                    .foregroundStyle(VitaColors.accentLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VitaTokens.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .fill(VitaColors.glassBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                            .stroke(VitaColors.glassBorder, lineWidth: 0.75)
                    )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.xl)
            .padding(.top, VitaTokens.Spacing.xs)
            .padding(.bottom, VitaTokens.Spacing._4xl)
        }
    }

    // MARK: - "Cartas para estudar hoje" (medidor + novas/revisar)

    private var todayCard: some View {
        let due = summary.due
        let news = summary.newCards
        let today = due + min(news, newPerDay)   // teto do aluno, não um 20 fixo
        return VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
            VStack(spacing: VitaTokens.Spacing.lg) {
                DeckGaugeView(
                    value: today,
                    total: max(totalCards, 1),
                    caption: "Cartas para estudar hoje"
                )
                HStack(spacing: VitaTokens.Spacing.md) {
                    miniStat(value: news, label: "Novas", tint: VitaColors.accentLight)
                    miniStat(value: due, label: "Para revisar", tint: VitaColors.accent)
                }
            }
            .padding(VitaTokens.Spacing.lg)
            .overlay(alignment: .topTrailing) {
                barButton(icon: "magnifyingglass") { showBrowser = true }
                    .padding(VitaTokens.Spacing.md)
            }
        }
    }

    /// Carrossel com algumas cartas reais do baralho, pra decidir o download
    /// olhando o conteudo — nao o nome. Some assim que o baralho e baixado.
    @ViewBuilder
    private var amostraSection: some View {
        if amostraFalhou {
            HStack(spacing: VitaTokens.Spacing.xs) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 12, weight: .medium))  // ds-allow: ícone do aviso de amostra
                    .foregroundStyle(VitaColors.textTertiary)
                Text("Não consegui carregar os exemplos agora.")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
        } else if let amostra, !amostra.cards.isEmpty {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                HStack(spacing: VitaTokens.Spacing.xs) {
                    Text("Amostra do baralho")
                        .font(VitaTypography.labelLarge)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("\(amostra.cards.count) de \(amostra.totalCards)")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VitaTokens.Spacing.md) {
                        ForEach(amostra.cards, id: \.id) { card in
                            amostraCard(card)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                // O scroll horizontal sangra ate a borda: cortar no padding do
                // pai faria a proxima carta sumir em vez de espiar.
                .padding(.horizontal, -VitaTokens.Spacing.lg)
                .padding(.leading, VitaTokens.Spacing.lg)
            }
        }
    }

    private func amostraCard(_ card: LibraryDeckSampleCard) -> some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
            Text(FlashcardHTMLReader.preview(card.front))
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            if let verso = card.back.flatMap({ $0 }),
               case let texto = FlashcardHTMLReader.preview(verso), !texto.isEmpty {
                Text(texto)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(VitaTokens.Spacing.md)
        .frame(width: 208, height: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(VitaColors.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .stroke(VitaColors.glassBorder, lineWidth: 0.75)
        )
    }

    private func miniStat(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            CountUpText(value: value, font: VitaTypography.headlineSmall)
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VitaTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(VitaColors.surfaceCard.opacity(0.5))
        )
    }

    /// CTA único e honesto: baralho da Biblioteca só estuda DEPOIS de baixado
    /// (nada de conteúdo vem embarcado na apk). Enquanto não baixou, o botão é
    /// "Baixar baralho"; baixando, vira a própria barra de progresso.
    @ViewBuilder
    private var primaryCTA: some View {
        if let slug = librarySlug, !downloads.isDownloaded(slug) {
            switch downloads.state(for: slug) {
            case .downloading(let progress):
                downloadingCTA(slug: slug, progress: progress)
            case .installing:
                ctaShell(filled: true) {
                    HStack(spacing: VitaTokens.Spacing.sm) {
                        ProgressView().tint(VitaColors.surface)
                        Text("Preparando os cartões...")
                            .font(VitaTypography.labelLarge)
                    }
                }
            case .failed(let message):
                VStack(spacing: VitaTokens.Spacing.xs) {
                    Button {
                        downloads.clearError(slug: slug)
                        downloads.download(slug: slug, title: title, tokenStore: container.tokenStore)
                    } label: {
                        ctaShell(filled: true) {
                            Text("Tentar baixar de novo").font(VitaTypography.labelLarge)
                        }
                    }
                    .buttonStyle(.plain)
                    Text(message)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.dataRed)
                        .multilineTextAlignment(.center)
                }
            case .idle:
                Button {
                    downloads.download(slug: slug, title: title, tokenStore: container.tokenStore)
                } label: {
                    ctaShell(filled: true) {
                        HStack(spacing: VitaTokens.Spacing.sm) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 15, weight: .bold))  // ds-allow: ícone do CTA
                            Text("Baixar baralho")
                                .font(VitaTypography.labelLarge)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("deck_home_download")
            }
        } else {
            Button { onStudy(deckId) } label: {
                ctaShell(filled: true) {
                    HStack(spacing: VitaTokens.Spacing.sm) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))  // ds-allow: ícone do CTA
                        Text("Estudar")
                            .font(VitaTypography.labelLarge)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("deck_home_study")
        }
    }

    /// Enquanto baixa, o próprio CTA é a barra: preenche da esquerda pra direita.
    private func downloadingCTA(slug: String, progress: DeckDownloadManager.Progress) -> some View {
        Button { downloads.cancel(slug: slug) } label: {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                        .fill(VitaColors.surfaceCard)
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [VitaColors.accent, VitaColors.accentLight],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * max(0.02, progress.fraction))
                        .shadow(color: VitaColors.accent.opacity(0.55), radius: 10)
                    HStack {
                        // Porcentagem + tamanho + velocidade + tempo restante.
                        // Sem esses números um download lento e um travado são
                        // idênticos na tela, e o aluno não sabe se espera.
                        VStack(alignment: .leading, spacing: 2) {
                            Text(progress.total > 0
                                 ? "Baixando \(Int(progress.fraction * 100))%"
                                 : "Baixando…")
                                .font(VitaTypography.labelLarge)
                                .foregroundStyle(VitaColors.textPrimary)
                            Text(
                                [progress.sizeText, progress.speedText, progress.etaText]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · ")
                            )
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                        }
                        Spacer()
                        Text("Cancelar")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .padding(.horizontal, VitaTokens.Spacing.lg)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                        .stroke(VitaColors.glassBorder, lineWidth: 0.75)
                )
            }
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("deck_home_downloading")
    }

    private func ctaShell(filled: Bool, @ViewBuilder content: () -> some View) -> some View {
        content()
            .foregroundStyle(filled ? VitaColors.surface : VitaColors.accentLight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VitaTokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                    .fill(filled ? VitaColors.accent : VitaColors.glassBg)
            )
    }

    // MARK: - Nota + distribuição de respostas

    private var scoreCard: some View {
        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    CountUpText(value: summary.scorePercent, font: VitaTypography.headlineLarge)
                        .accessibilityHidden(true)
                        .foregroundStyle(VitaColors.accent)
                    Text("%")
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.accent)
                    Text("NOTA")
                        .font(VitaTypography.labelSmall)
                        .kerning(1.1)
                        .foregroundStyle(VitaColors.textTertiary)
                        .padding(.leading, 4)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Nota")
                .accessibilityValue("\(summary.scorePercent) por cento")

                ratingBar

                HStack(spacing: 0) {
                    ratingLegend("Novamente", summary.ratings[0], VitaColors.dataRed)
                    ratingLegend("Difícil", summary.ratings[1], VitaColors.dataAmber)
                    ratingLegend("Bom", summary.ratings[2], VitaColors.dataGreen)
                    ratingLegend("Fácil", summary.ratings[3], VitaColors.accentLight)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(VitaTokens.Spacing.lg)
        }
    }

    /// Barra empilhada com a proporção real de cada resposta (vazia = sem review).
    private var ratingBar: some View {
        let total = max(summary.ratings.reduce(0, +), 1)
        let colors: [Color] = [
            VitaColors.dataRed, VitaColors.dataAmber, VitaColors.dataGreen, VitaColors.accentLight,
        ]
        return GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(0..<4, id: \.self) { i in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [colors[i], colors[i].opacity(0.65)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(summary.ratings[i]) / CGFloat(total) * barFill)
                        .shadow(color: colors[i].opacity(0.5), radius: 4)
                }
                if summary.ratings.reduce(0, +) == 0 {
                    Rectangle().fill(VitaColors.surfaceCard)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
        .accessibilityHidden(true)   // a legenda abaixo já fala os números
    }

    private func ratingLegend(_ label: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 4) {
                Circle().fill(tint).frame(width: 7, height: 7)
                Text("\(value)")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Compartilhar (.apkg — abre no Anki também)

    private func share() {
        guard let slug = librarySlug else {
            // Baralho do aluno: compartilhar entra junto com a Comunidade
            // (publicar). Por ora só a Biblioteca exporta pack pronto.
            return
        }
        preparingShare = true
        Task { @MainActor in
            defer { preparingShare = false }
            guard let url = URL(string: "\(AppConfig.apiBaseURL)/study/flashcards/library/\(slug)/pack") else { return }
            var request = URLRequest(url: url)
            request.timeoutInterval = 600
            if let token = await container.tokenStore.token {
                request.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
                request.setValue(token, forHTTPHeaderField: "X-Extension-Token")
            }
            guard let (tmp, response) = try? await URLSession.shared.download(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(title).apkg")
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.moveItem(at: tmp, to: dest)
            sharePack = dest
            showShare = true
        }
    }

    private func barButton(icon: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))  // ds-allow: ícone da app bar (área de toque)
                .foregroundStyle(prominent ? VitaColors.surface : VitaColors.accent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(prominent ? VitaColors.accent : VitaColors.glassBg))
                .overlay(Circle().stroke(prominent ? Color.clear : VitaColors.glassBorder, lineWidth: 0.75))
                // Alvo de toque de 44pt (HIG) sem inchar o círculo visível.
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func load() async {
        await downloads.refreshInstalled()
        // Falhar aqui não pode zerar o medidor: mantém o padrão do Anki (20).
        if let ajustes = try? await container.api.getFlashcardSettings() {
            newPerDay = ajustes.newPerDay
        }
        // Amostra só faz sentido pro que ainda NAO foi baixado: depois do
        // download os cards vem do proprio pack.
        if let slug = librarySlug, !downloads.isDownloaded(slug) {
            do {
                amostra = try await container.api.getLibraryDeckSample(slug: slug, limit: 5)
                amostraFalhou = false
            } catch {
                // `try?` aqui apagou o erro e a secao sumiu sem explicacao — o
                // servidor devolvia 404 (rota ainda nao publicada) e a tela
                // fingia que estava tudo certo. Rafael 2026-07-21.
                amostra = nil
                amostraFalhou = true
                deckLog.error("amostra da Biblioteca falhou (\(slug)): \(error)")
            }
        } else {
            amostra = nil
            amostraFalhou = false
        }
        if let slug = librarySlug {
            // Biblioteca: os cards vêm do pack baixado ou do bundle — offline.
            let cards = await VitaContentBundle.shared.cards(disciplineSlug: slug)
            summary = await LocalFlashcardStore.shared.deckSummary(cardIds: cards.map(\.id))
            // Título = nome da DISCIPLINA (Anatomia), nunca o `deckTitle` do card
            // — no acervo curado ele é o deck-mãe ("Medicina") e mostrava o nome
            // errado no topo.
            if deck == nil {
                deck = FlashcardDeckEntry(id: deckId, title: deckTitle ?? slug, totalCards: cards.count)
            }
        } else {
            if let decks = try? await container.api.getFlashcardDecks(deckLimit: 2000, summary: false) {
                deck = decks.first(where: { $0.id == deckId })
            }
            let ids = deck?.cards.map(\.id) ?? []
            summary = await LocalFlashcardStore.shared.deckSummary(cardIds: ids)
            if summary.total == 0 { summary.total = deck?.cardCount ?? 0 }
        }
        loading = false
    }
}

// MARK: - Medidor semicircular ("Cartas para estudar hoje")

private struct DeckGaugeView: View {
    let value: Int
    let total: Int
    let caption: String

    /// Progresso da animação de entrada (0→1): o arco preenche e o número sobe
    /// junto. Uma curva só governa os dois — eles chegam no fim no mesmo instante.
    @State private var animation: Double = 0
    /// Reduce Motion ligado = sem contagem, sem varredura do arco: valor final direto.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(value) / Double(total))
    }

    /// Fração desenhada agora (mínimo visível pra a ponta luminosa aparecer).
    private var drawn: Double { max(fraction * animation, 0.012) }

    private var displayValue: Int { Int((Double(value) * animation).rounded()) }

    /// Ângulo da ponta do arco — onde mora o brilho especular que "corre" junto.
    private var tipAngle: Angle { .degrees(180 + 180 * drawn) }

    private func play(duration: Double) {
        guard !reduceMotion else { animation = 1; return }
        // Desacelera no fim (o número "assenta" no lugar em vez de estancar).
        withAnimation(.easeOut(duration: duration)) { animation = 1 }
    }

    var body: some View {
        ZStack {
            // Trilho afundado: sombra interna simulada por um gradiente escuro —
            // a canaleta onde o arco corre (canon §2.12: recesso).
            GaugeArc(fraction: 1)
                .stroke(
                    LinearGradient(
                        colors: [Color.black.opacity(0.55), VitaColors.surfaceCard],
                        startPoint: .top, endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
            GaugeArc(fraction: 1)
                .stroke(VitaColors.glassBorder.opacity(0.5), style: StrokeStyle(lineWidth: 0.75))
                .blendMode(.overlay)

            // Halo largo e difuso: a luz que o arco JOGA na canaleta ao redor.
            GaugeArc(fraction: drawn)
                .stroke(VitaColors.accent.opacity(0.55), style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .blur(radius: 12)

            // Corpo do arco: gradiente angular (a luz nasce fraca à esquerda e
            // ganha corpo até a ponta) + dupla sombra colorida = matéria acesa.
            GaugeArc(fraction: drawn)
                .stroke(
                    AngularGradient(
                        colors: [
                            VitaColors.accent.opacity(0.75),
                            VitaColors.accent,
                            VitaColors.accentLight,
                            Color.white.opacity(0.92),
                        ],
                        center: .init(x: 0.5, y: 1.0),
                        startAngle: .degrees(180),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .shadow(color: VitaColors.accent.opacity(0.65), radius: 10, y: 2)
                .shadow(color: VitaColors.accentLight.opacity(0.4), radius: 22)

            // Fio especular no topo do traço — reflexo da luz de cima na peça.
            GaugeArc(fraction: drawn)
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .blur(radius: 1.5)
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.15), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Ponta viva: bolinha luminosa que corre com o preenchimento.
            // (ocupa o mesmo espaço do arco — a geometria tem que bater)
            GaugeTip(angle: tipAngle)
                .fill(Color.white)
                .shadow(color: VitaColors.accentLight, radius: 8)
                .shadow(color: VitaColors.accent.opacity(0.8), radius: 16)

            VStack(spacing: 2) {
                Text("\(displayValue)")
                    .font(VitaTypography.displayLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .shadow(color: VitaColors.accent.opacity(0.35 * animation), radius: 12)
                Text(caption)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .offset(y: 10)
        }
        .frame(height: 150)
        .padding(.top, VitaTokens.Spacing.sm)
        // VoiceOver lê o medidor como UMA frase; sem isto ele solta o número
        // cru sem dizer do que se trata.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue("\(value) de \(total) cartões")
        .onAppear { play(duration: 1.1) }
        .onChange(of: value) { _, _ in
            if !reduceMotion { animation = 0 }
            play(duration: 0.9)
        }
    }
}

/// Número que sobe de 0 até o valor ao aparecer — o mesmo ritmo do arco.
/// Usado nos contadores da tela do baralho (Novas / Para revisar / nota).
struct CountUpText: View {
    let value: Int
    var font: Font = VitaTypography.headlineSmall
    var duration: Double = 1.0

    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(Int(shown.rounded()))")
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear { animate() }
            .onChange(of: value) { _, _ in
                if !reduceMotion { shown = 0 }
                animate()
            }
    }

    private func animate() {
        guard !reduceMotion else { shown = Double(value); return }
        withAnimation(.easeOut(duration: duration)) { shown = Double(value) }
    }
}

/// Ponto na ponta do arco — MESMA geometria do GaugeArc (ocupa o espaço inteiro
/// e desenha só a bolinha), senão a luz não pousa em cima do traço.
private struct GaugeTip: Shape {
    var angle: Angle
    var dotRadius: CGFloat = 4.5

    /// Deixa a bolinha acompanhar a animação do arco (mesma curva).
    var animatableData: Double {
        get { angle.degrees }
        set { angle = .degrees(newValue) }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY - 12)
        let radius = min(rect.width, rect.height * 2) / 2 - 12
        let point = CGPoint(
            x: center.x + radius * cos(angle.radians),
            y: center.y + radius * sin(angle.radians)
        )
        return Path(ellipseIn: CGRect(
            x: point.x - dotRadius, y: point.y - dotRadius,
            width: dotRadius * 2, height: dotRadius * 2
        ))
    }
}

private struct GaugeArc: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY - 12)
        let radius = min(rect.width, rect.height * 2) / 2 - 12
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(180 + 180 * fraction),
            clockwise: false
        )
        return path
    }
}
