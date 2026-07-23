import SwiftUI

// MARK: - Sua ofensiva

/// Tela de detalhe da ofensiva: herói, plantão coberto, calendário e marcos.
///
/// Abre ao tocar na chama. O dia é sempre o que o SERVIDOR diz (ele corta em
/// America/Sao_Paulo); o aparelho nunca decide o que é "hoje" — senão quem
/// viaja ou mexe no relógio vê uma ofensiva diferente da real.
struct OfensivaScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container

    @State private var ofensiva = Ofensiva()
    @State private var mesVisivel = Date()
    @State private var carregando = true
    @State private var erro: String?

    /// Fuso do corte do dia — o mesmo do motor de gamificação.
    private static let fusoBrasil = TimeZone(identifier: "America/Sao_Paulo") ?? .current

    private var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = Self.fusoBrasil
        c.firstWeekday = 1 // domingo, como no calendário brasileiro
        return c
    }

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: VitaTokens.Spacing.lg) {
                    cartaoHeroi
                    cartaoPlantao
                    cartaoCalendario
                    cartaoMarcos
                    Color.clear.frame(height: VitaTokens.Spacing._4xl)
                }
                .padding(.horizontal, VitaTokens.Spacing.lg)
                .padding(.top, VitaTokens.Spacing.sm)
            }
            .opacity(carregando || erro != nil ? 0 : 1)

            if carregando {
                ProgressView().tint(VitaColors.accent)
            } else if let erro {
                // Mostrar "0 dias" quando a resposta nao chegou e mentir: some
                // com a ofensiva de quem tem uma viva. O erro aparece.
                VitaErrorState(
                    title: "Nao consegui carregar sua ofensiva",
                    message: erro,
                    systemImage: "flame",
                    onRetry: { Task { carregando = true; await carregar() } }
                )
                .padding(.horizontal, VitaTokens.Spacing.lg)
            }
        }
        .navigationTitle("Sua ofensiva")
        .navigationBarTitleDisplayMode(.inline)
        .task { await carregar() }
        .refreshable { await carregar() }
    }

    // MARK: Herói

    private var cartaoHeroi: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: VitaTokens.Spacing.sm) {
                ChamaOfensiva(ativa: ofensiva.currentStreak > 0, tamanho: 34)
                Text("\(ofensiva.currentStreak)")
                    .font(PixioTypo.sans(size: 52, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(ofensiva.currentStreak == 1 ? "dia" : "dias")
                    .font(VitaTypography.headlineSmall)
                    .padding(.leading, -VitaTokens.Spacing.xxs)
                Spacer(minLength: 0)
            }
            .foregroundStyle(VitaColors.surface)

            Text(fraseDoHeroi)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.surface.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VitaTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.xl, style: .continuous)
                .fill(LinearGradient(colors: [VitaColors.accentHover, VitaColors.accent],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    /// A frase é o que dá sentido ao número. Cada estado tem a sua — inclusive
    /// o dia em que a pessoa ainda não estudou, que é quando o empurrão importa.
    private var fraseDoHeroi: String {
        if ofensiva.currentStreak == 0 {
            return "Sua ofensiva começa no primeiro bloco de estudo. Um baralho de flashcards já conta."
        }
        if !ofensiva.studiedToday {
            return "Você ainda não estudou hoje. Estude para manter a sequência viva."
        }
        if ofensiva.eRecordePessoal {
            return "Recorde pessoal. Cada dia agora é história nova."
        }
        if let faltam = ofensiva.diasParaRecorde {
            return faltam == 1
                ? "Falta 1 dia para empatar seu recorde de \(ofensiva.longestStreak)."
                : "Faltam \(faltam) dias para empatar seu recorde de \(ofensiva.longestStreak)."
        }
        return "Sequência viva. Continue."
    }

    // MARK: Plantão coberto

    private var cartaoPlantao: some View {
        HStack(alignment: .top, spacing: VitaTokens.Spacing.md) {
            Image(systemName: "shield.fill")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.accent)

            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                Text(ofensiva.freezesAvailable > 0 ? "Plantão coberto" : "Sem plantão guardado")
                    .font(VitaTypography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(textoDoPlantao)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(VitaTokens.Spacing.lg)
        .glassCard(cornerRadius: VitaTokens.Radius.lg)
    }

    private var textoDoPlantao: String {
        if ofensiva.freezesAvailable > 0 {
            let n = ofensiva.freezesAvailable
            return n == 1
                ? "Perdeu um dia? Um plantão cobre por você e a sequência segue. Você tem 1 guardado — recarrega a cada 7 dias seguidos."
                : "Perdeu um dia? O plantão cobre por você. Você tem \(n) guardados — recarregam a cada 7 dias seguidos."
        }
        return "Você já usou o seu. Sete dias seguidos de estudo e ele volta."
    }

    // MARK: Calendário

    private var cartaoCalendario: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            HStack {
                botaoMes(-1, icone: "chevron.left")
                Text(nomeDoMes(mesVisivel))
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(minWidth: 110)
                botaoMes(1, icone: "chevron.right")
                Spacer(minLength: 0)
                legenda(icone: "flame.fill", texto: "estudou")
                legenda(icone: "shield.fill", texto: "coberto")
            }

            HStack(spacing: 0) {
                ForEach(Array(["D", "S", "T", "Q", "Q", "S", "S"].enumerated()), id: \.offset) { _, dia in
                    Text(dia)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(semanasDoMes.enumerated()), id: \.offset) { _, semana in
                HStack(spacing: 0) {
                    ForEach(Array(semana.enumerated()), id: \.offset) { _, dia in
                        celulaDoDia(dia)
                    }
                }
            }
        }
        .padding(VitaTokens.Spacing.lg)
        .glassCard(cornerRadius: VitaTokens.Radius.lg)
    }

    private func botaoMes(_ delta: Int, icone: String) -> some View {
        Button {
            guard let novo = calendario.date(byAdding: .month, value: delta, to: mesVisivel) else { return }
            mesVisivel = novo
            Task { await carregar() }
        } label: {
            Image(systemName: icone)
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.accent)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta < 0 ? "Mês anterior" : "Próximo mês")
    }

    private func legenda(icone: String, texto: String) -> some View {
        HStack(spacing: VitaTokens.Spacing.xxs) {
            Image(systemName: icone).font(PixioTypo.sans(size: 9))
            Text(texto).font(VitaTypography.labelSmall)
        }
        .foregroundStyle(VitaColors.textTertiary)
    }

    @ViewBuilder
    private func celulaDoDia(_ dia: Date?) -> some View {
        if let dia {
            let iso = Self.formatadorIso.string(from: dia)
            let marca = ofensiva.days.first { $0.date == iso }
            let futuro = dia > Date()

            ZStack {
                switch marca?.kind {
                case .study:
                    Circle().fill(VitaColors.accent.opacity(0.18))
                    Image(systemName: "flame.fill")
                        .font(PixioTypo.sans(size: 13))
                        .foregroundStyle(VitaColors.accent)
                case .covered:
                    Circle().strokeBorder(VitaColors.accent.opacity(0.45), lineWidth: 1)
                    Image(systemName: "shield.fill")
                        .font(PixioTypo.sans(size: 11))
                        .foregroundStyle(VitaColors.accent.opacity(0.75))
                case nil:
                    Text("\(calendario.component(.day, from: dia))")
                        .font(VitaTypography.labelMedium)
                        .monospacedDigit()
                        .foregroundStyle(futuro ? VitaColors.textTertiary.opacity(0.45)
                                                : VitaColors.textSecondary)
                }
            }
            .frame(width: 34, height: 34)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VitaTokens.Spacing.xxs)
            .accessibilityLabel(rotuloAcessivel(dia: dia, marca: marca))
        } else {
            Color.clear.frame(height: 34).frame(maxWidth: .infinity)
        }
    }

    private func rotuloAcessivel(dia: Date, marca: DiaOfensiva?) -> String {
        let n = calendario.component(.day, from: dia)
        switch marca?.kind {
        case .study: return "Dia \(n): estudou"
        case .covered: return "Dia \(n): coberto pelo plantão"
        case nil: return "Dia \(n)"
        }
    }

    // MARK: Marcos

    private var cartaoMarcos: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            Text("MARCOS")
                .font(VitaTypography.labelSmall)
                .tracking(VitaTokens.Typography.letterSpacingWide)
                .foregroundStyle(VitaColors.textTertiary)

            HStack(spacing: VitaTokens.Spacing.sm) {
                ForEach(ofensiva.milestones) { marco in
                    VStack(spacing: VitaTokens.Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(marco.reached ? VitaColors.accent.opacity(0.16) : Color.clear)
                            Circle()
                                .strokeBorder(marco.reached ? VitaColors.accent.opacity(0.55)
                                                            : VitaColors.glassBorder,
                                              lineWidth: 1)
                            Image(systemName: marco.reached ? "flame.fill" : "lock.fill")
                                .font(PixioTypo.sans(size: marco.reached ? 17 : 13))
                                .foregroundStyle(marco.reached ? VitaColors.accent
                                                               : VitaColors.textTertiary.opacity(0.5))
                        }
                        .frame(height: 52)

                        Text("\(marco.days) dias")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(marco.reached ? VitaColors.textPrimary
                                                           : VitaColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(VitaTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: VitaTokens.Radius.lg)
    }

    // MARK: Dados

    private static let formatadorIso: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let formatadorMesApi: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private func nomeDoMes(_ data: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = Self.fusoBrasil
        f.dateFormat = "LLLL"
        return f.string(from: data).capitalized
    }

    /// Grade do mês: nil onde a célula é de outro mês.
    private var semanasDoMes: [[Date?]] {
        guard let intervalo = calendario.dateInterval(of: .month, for: mesVisivel),
              let total = calendario.range(of: .day, in: .month, for: mesVisivel)?.count
        else { return [] }

        let primeiroPeso = calendario.component(.weekday, from: intervalo.start) - calendario.firstWeekday
        let vazios = (primeiroPeso + 7) % 7

        var celulas: [Date?] = Array(repeating: nil, count: vazios)
        for offset in 0..<total {
            celulas.append(calendario.date(byAdding: .day, value: offset, to: intervalo.start))
        }
        while celulas.count % 7 != 0 { celulas.append(nil) }

        return stride(from: 0, to: celulas.count, by: 7).map { Array(celulas[$0..<$0 + 7]) }
    }

    private func carregar() async {
        erro = nil
        do {
            let mes = Self.formatadorMesApi.string(from: mesVisivel)
            let resposta = try await container.api.getOfensiva(month: mes)
            await MainActor.run {
                ofensiva = resposta
                carregando = false
            }
        } catch {
            // Falhar em silêncio aqui mostraria "0 dias" pra quem tem ofensiva
            // viva — mentira pior que o erro.
            await MainActor.run {
                ofensiva = Ofensiva()
                erro = error.localizedDescription
                carregando = false
            }
        }
    }
}

// MARK: - Chama

/// A chama que pulsa. Mesma linguagem do VitaStreakBadge (1.0 → 1.12 em 800 ms),
/// em tamanho livre para o herói e para a comemoração.
struct ChamaOfensiva: View {
    let ativa: Bool
    var tamanho: CGFloat = 28

    @State private var pulso: CGFloat = 1.0

    var body: some View {
        Image(systemName: "flame.fill")
            .font(PixioTypo.sans(size: tamanho, weight: .semibold))
            .scaleEffect(ativa ? pulso : 1)
            .onAppear {
                guard ativa else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulso = 1.12
                }
            }
            .accessibilityHidden(true)
    }
}
