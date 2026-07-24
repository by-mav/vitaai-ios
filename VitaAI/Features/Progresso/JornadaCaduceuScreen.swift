import SwiftUI

// MARK: - JornadaCaduceuScreen — bancada de design da Jornada (isolada)
//
// Abre por launch-arg DEBUG "--preview-jornada-caduceu" (padrão do
// --preview-onboarding). Peça do MUNDO da trilha (TrailWorld, DESIGN.md §5).
//
// A peça (Rafael 2026-07-23, TERCEIRA rodada — referência: mockup Vita claro):
//   • o "Tudo" MORRE; o caduceu assume o lugar dele — plaquinha e topnav são
//     UM BLOCO SÓ;
//   • caduceu com 3× a altura da barra, canto superior esquerdo (posição do
//     logo "Vita" na referência), descendo até a linha das disciplinas;
//   • chevron EMBAIXO do caduceu, abrindo PRA BAIXO;
//   • 3 andares à direita: (1) fogo/moeda/hambúrguer intocados, (2) cards das
//     GRANDES ÁREAS (6 canônicas), (3) fileira das DISCIPLINAS da área
//     selecionada (órgãos coloridos do claudereference.html);
//   • card de área ≈ metade de baixo do caduceu (~72pt);
//   • clique: área filtra a Jornada; disciplina refina; tocar a ativa desliga
//     (MESMA semântica do JornadaFiltroSheet).

struct JornadaCaduceuScreen: View {
    @StateObject private var injecao = ObservadorDeInjecao()
    @State private var expandida = false
    @State private var areaSel: String?
    @State private var discSel: String?
    @State private var mostradasAreas = 0
    @State private var mostradasDisc = 0

    private let areas = AreaBancada.canonicas

    var body: some View {
        ZStack {
            LinearGradient(colors: [TrailWorld.fieldTop, TrailWorld.fieldBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PlacaJornadaUnificada(
                    expandida: expandida,
                    areas: areas,
                    areaSel: areaSel,
                    discSel: discSel,
                    mostradasAreas: mostradasAreas,
                    mostradasDisc: mostradasDisc,
                    aoTocarChevron: alternar,
                    aoTocarArea: tocarArea,
                    aoTocarDisciplina: tocarDisciplina
                )
                .padding(.horizontal, 12)
                .padding(.top, 12)

                Spacer(minLength: 0)
            }
        }
        .task {
            // entrada da bancada: expande sozinha pra mostrar o gesto
            try? await Task.sleep(for: .milliseconds(650))
            if !expandida { alternar() }
        }
        .id(injecao.tick)   // hot reload: re-renderiza ao injetar arquivo salvo
    }

    /// Chevron: abre revelando as áreas UMA POR UMA; fecha recolhendo tudo.
    private func alternar() {
        HapticManager.shared.fire(.light)
        if expandida {
            withAnimation(.easeIn(duration: 0.18)) {
                mostradasAreas = 0
                mostradasDisc = 0
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85).delay(0.12)) {
                expandida = false
            }
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) { expandida = true }
            Task {
                for i in 1...areas.count {
                    try? await Task.sleep(for: .milliseconds(90))
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                        mostradasAreas = i
                    }
                }
                // referência: abre já com uma área ativa mostrando o 3º andar
                if areaSel == nil { tocarArea(areas[1]) }
            }
        }
    }

    /// Área: seleciona e revela as disciplinas dela; tocar a ativa desliga
    /// (volta pra "medicina inteira" = o caduceu).
    private func tocarArea(_ a: AreaBancada) {
        let jaAtiva = areaSel == a.slug
        HapticManager.shared.fire(jaAtiva ? .light : .medium)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            areaSel = jaAtiva ? nil : a.slug
            discSel = nil
            mostradasDisc = 0
        }
        guard !jaAtiva else { return }
        Task {
            for i in 1...a.disciplinas.count {
                try? await Task.sleep(for: .milliseconds(70))
                withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                    mostradasDisc = i
                }
            }
        }
    }

    private func tocarDisciplina(_ d: DisciplinaBancada) {
        let jaAtiva = discSel == d.slug
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            discSel = jaAtiva ? nil : d.slug
        }
        HapticManager.shared.fire(jaAtiva ? .light : .medium)
    }
}

// MARK: - Dados da bancada (6 áreas canônicas; disciplinas de amostra)

struct AreaBancada: Identifiable {
    let slug: String
    let nome: String
    let simbolo: String?      // SF Symbol do tile; nil = glifo de texto
    let glifo: String?        // fallback texto (♀ da GO)
    let corTopo: Color
    let corBase: Color
    let disciplinas: [DisciplinaBancada]
    var id: String { slug }

    static let canonicas: [AreaBancada] = [
        .init(slug: "ciclo-basico", nome: "Ciclo Básico",
              simbolo: "book.fill", glifo: nil,
              corTopo: Color(red: 0.62, green: 0.55, blue: 0.98),   // ds-allow: arte gamificada (mundo da trilha)
              corBase: Color(red: 0.36, green: 0.28, blue: 0.78),   // ds-allow: arte gamificada (mundo da trilha)
              disciplinas: [
                .init(slug: "anatomia", nome: "Anatomia", orgao: .coracao, progresso: 0.81),
                .init(slug: "fisiologia", nome: "Fisiologia", orgao: .pulmao, progresso: 0.64),
                .init(slug: "farmacologia", nome: "Farmaco", orgao: .rim, progresso: 0.47),
              ]),
        .init(slug: "clinica-medica", nome: "Clínica Médica",
              simbolo: "stethoscope", glifo: nil,
              corTopo: Color(red: 0.42, green: 0.72, blue: 0.98),   // ds-allow: arte gamificada (mundo da trilha)
              corBase: Color(red: 0.15, green: 0.42, blue: 0.78),   // ds-allow: arte gamificada (mundo da trilha)
              disciplinas: [
                .init(slug: "cardiologia", nome: "Cardiologia", orgao: .coracao, progresso: 0.72),
                .init(slug: "pneumologia", nome: "Pneumologia", orgao: .pulmao, progresso: 0.64),
                .init(slug: "nefrologia", nome: "Nefrologia", orgao: .rim, progresso: 0.81),
                .init(slug: "endocrinologia", nome: "Endócrino", orgao: .tireoide, progresso: 0.68),
                .init(slug: "gastroenterologia", nome: "Gastro", orgao: .estomago, progresso: 0.59),
                .init(slug: "infectologia", nome: "Infecto", orgao: .virus, progresso: 0.73),
              ]),
        .init(slug: "cirurgia", nome: "Cirurgia",
              simbolo: "scissors", glifo: nil,
              corTopo: Color(red: 0.55, green: 0.85, blue: 0.45),   // ds-allow: arte gamificada (mundo da trilha)
              corBase: Color(red: 0.22, green: 0.52, blue: 0.18),   // ds-allow: arte gamificada (mundo da trilha)
              disciplinas: [
                .init(slug: "cir-geral", nome: "Cir. Geral", orgao: .estomago, progresso: 0.52),
                .init(slug: "urologia", nome: "Urologia", orgao: .rim, progresso: 0.44),
              ]),
        .init(slug: "go", nome: "GO",
              simbolo: nil, glifo: "♀",
              corTopo: Color(red: 0.98, green: 0.55, blue: 0.68),   // ds-allow: arte gamificada (mundo da trilha)
              corBase: Color(red: 0.75, green: 0.25, blue: 0.42),   // ds-allow: arte gamificada (mundo da trilha)
              disciplinas: [
                .init(slug: "obstetricia", nome: "Obstetrícia", orgao: .estomago, progresso: 0.61),
                .init(slug: "ginecologia", nome: "Ginecologia", orgao: .tireoide, progresso: 0.55),
              ]),
        .init(slug: "pediatria", nome: "Pediatria",
              simbolo: "teddybear.fill", glifo: nil,
              corTopo: Color(red: 0.99, green: 0.83, blue: 0.42),   // ds-allow: arte gamificada (mundo da trilha)
              corBase: Color(red: 0.82, green: 0.56, blue: 0.12),   // ds-allow: arte gamificada (mundo da trilha)
              disciplinas: [
                .init(slug: "neonatologia", nome: "Neonato", orgao: .coracao, progresso: 0.49),
                .init(slug: "ped-geral", nome: "Ped. Geral", orgao: .pulmao, progresso: 0.66),
              ]),
        .init(slug: "preventiva", nome: "Preventiva",
              simbolo: "shield.fill", glifo: nil,
              corTopo: Color(red: 0.36, green: 0.85, blue: 0.68),   // ds-allow: arte gamificada (mundo da trilha)
              corBase: Color(red: 0.10, green: 0.52, blue: 0.40),   // ds-allow: arte gamificada (mundo da trilha)
              disciplinas: [
                .init(slug: "epidemio", nome: "Epidemio", orgao: .virus, progresso: 0.70),
                .init(slug: "saude-coletiva", nome: "S. Coletiva", orgao: .rim, progresso: 0.58),
              ]),
    ]
}

struct DisciplinaBancada: Identifiable {
    let slug: String
    let nome: String
    let orgao: OrgaoIcone.Orgao
    let progresso: Double
    var id: String { slug }
}

// MARK: - A placa unificada (caduceu + topnav + 2 andares, UM bloco só)

private struct PlacaJornadaUnificada: View {
    let expandida: Bool
    let areas: [AreaBancada]
    let areaSel: String?
    let discSel: String?
    let mostradasAreas: Int
    let mostradasDisc: Int
    let aoTocarChevron: () -> Void
    let aoTocarArea: (AreaBancada) -> Void
    let aoTocarDisciplina: (DisciplinaBancada) -> Void

    // barra tem 48; o caduceu expandido tem o TRIPLO (chega na 3ª linha)
    private let barra: CGFloat = 48
    private var alturaCaduceu: CGFloat { expandida ? barra * 3 : barra }
    private let larguraCaduceu: CGFloat = 64

    private var areaAtiva: AreaBancada? {
        areas.first(where: { $0.slug == areaSel })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                colunaCaduceu

                VStack(alignment: .leading, spacing: 10) {
                    barraStatus
                    if expandida { andarAreas }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            if expandida, let area = areaAtiva {
                andarDisciplinas(area)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 10)
        .background(tabua)
    }

    // MARK: coluna do caduceu (no lugar do "Tudo"; chevron EMBAIXO)

    private var colunaCaduceu: some View {
        VStack(spacing: 1) {
            CaduceuMiniArte()
                .frame(width: larguraCaduceu, height: alturaCaduceu)

            Button(action: aoTocarChevron) {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 20, weight: .bold))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(TrailWorld.fireflyGold)
                    .shadow(color: TrailWorld.fireflyGold.opacity(0.8), radius: 5)
                    .rotationEffect(.degrees(expandida ? 180 : 0))
                    .frame(width: larguraCaduceu, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("jornada_caduceu_chevron")
            .accessibilityLabel(expandida ? "Fechar áreas" : "Abrir áreas")
        }
    }

    // MARK: andar 1 — fogo/moeda/hambúrguer (receita do TrailTopPlaca, intocada)

    private var barraStatus: some View {
        HStack(spacing: 11) {
            divisor

            HStack(spacing: 6) {
                chama
                numero("12", cor: Self.brasa, sombra: Self.brasaSombra)
            }

            HStack(spacing: 6) {
                CoinIcon(size: 19)
                numero("3049", cor: Self.ouro, sombra: Self.ouroSombra)
            }

            Spacer(minLength: 0)
            divisor
            botaoMenu
        }
        .frame(height: barra)
    }

    // MARK: andar 2 — grandes áreas (um a um, tile colorido + label ouro)

    private var andarAreas: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Array(areas.enumerated()), id: \.element.slug) { i, a in
                    PlacaDeArea(
                        area: a,
                        ativa: areaSel == a.slug,
                        apagada: areaSel != nil && areaSel != a.slug
                    ) {
                        aoTocarArea(a)
                    }
                    .opacity(i < mostradasAreas ? 1 : 0)
                    .offset(y: i < mostradasAreas ? 0 : 10)
                    .scaleEffect(i < mostradasAreas ? 1 : 0.9, anchor: .top)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: andar 3 — disciplinas da área (órgãos, largura cheia da placa)

    private func andarDisciplinas(_ area: AreaBancada) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Array(area.disciplinas.enumerated()), id: \.element.slug) { i, d in
                    PlacaDeDisciplina(
                        disciplina: d,
                        ativa: discSel == d.slug,
                        apagada: discSel != nil && discSel != d.slug
                    ) {
                        aoTocarDisciplina(d)
                    }
                    .opacity(i < mostradasDisc ? 1 : 0)
                    .offset(x: i < mostradasDisc ? 0 : -14)
                    .scaleEffect(i < mostradasDisc ? 1 : 0.9, anchor: .leading)
                }
            }
            .padding(.vertical, 2)
        }
        .transition(.opacity)
    }

    // MARK: matéria da tábua (receita do TrailTopPlaca, um bloco só)

    private var tabua: some View {
        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
            .fill(
                LinearGradient(colors: [TrailWorld.trunkTop, TrailWorld.trunkBottom],
                               startPoint: .top, endPoint: .bottom)
                .shadow(.inner(color: TrailWorld.fireflyWarm.opacity(0.34), radius: 0, y: 2))
                .shadow(.inner(color: .black.opacity(0.45), radius: 4, y: -3))
            )
            .overlay(veio)
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .strokeBorder(TrailWorld.fireflyGold.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 0, y: 5)
            .shadow(color: .black.opacity(0.5), radius: 9, y: 10)
    }

    private var veio: some View {
        Canvas { ctx, size in
            for i in stride(from: 6.0, to: size.height - 4, by: 5.5) {
                var p = Path()
                p.move(to: CGPoint(x: 10, y: i))
                p.addLine(to: CGPoint(x: size.width - 10, y: i + 0.6))
                ctx.stroke(p, with: .color(.black.opacity(0.075)), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous))
        .allowsHitTesting(false)
        .transaction { $0.animation = nil }
    }

    private var divisor: some View {
        Rectangle()
            .fill(.black.opacity(0.42))
            .frame(width: 1, height: 24)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(TrailWorld.fireflyWarm.opacity(0.12))
                    .frame(width: 1)
                    .offset(x: 1)
            }
    }

    private var chama: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 18, weight: .semibold))  // ds-allow: arte gamificada (mundo da trilha)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.82, blue: 0.54),   // ds-allow: arte gamificada (mundo da trilha)
                             Color(red: 1.0, green: 0.54, blue: 0.24),   // ds-allow: arte gamificada (mundo da trilha)
                             Color(red: 0.88, green: 0.23, blue: 0.12)], // ds-allow: arte gamificada (mundo da trilha)
                    startPoint: .top, endPoint: .bottom
                )
            )
            .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.15).opacity(0.5), radius: 4)  // ds-allow: arte gamificada (mundo da trilha)
    }

    private var botaoMenu: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Self.tabuaMenu[i])
                    .frame(width: 21, height: 3.8)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(TrailWorld.fireflyWarm.opacity(0.8 - Double(i) * 0.12))
                            .frame(height: 1.3)
                    }
            }
        }
        .frame(width: 30, height: 30)
    }

    private func numero(_ texto: String, cor: Color, sombra: Color) -> some View {
        Text(verbatim: texto)
            .font(.system(size: 17, weight: .heavy, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
            .monospacedDigit()
            .foregroundStyle(cor)
            .shadow(color: sombra, radius: 0, y: 1)
    }

    private static let brasa = Color(red: 1.0, green: 0.48, blue: 0.27)  // ds-allow: arte gamificada (mundo da trilha)
    private static let brasaSombra = Color(red: 0.47, green: 0.08, blue: 0.0).opacity(0.6)  // ds-allow: arte gamificada (mundo da trilha)
    private static let ouro = Color(red: 1.0, green: 0.90, blue: 0.52)  // ds-allow: arte gamificada (mundo da trilha)
    private static let ouroSombra = Color(red: 0.31, green: 0.20, blue: 0.0).opacity(0.6)  // ds-allow: arte gamificada (mundo da trilha)
    private static let tabuaMenu: [Color] = [
        Color(red: 0.88, green: 0.77, blue: 0.59),  // ds-allow: arte gamificada (mundo da trilha)
        Color(red: 0.85, green: 0.75, blue: 0.56),  // ds-allow: arte gamificada (mundo da trilha)
        Color(red: 0.79, green: 0.68, blue: 0.49),  // ds-allow: arte gamificada (mundo da trilha)
    ]
}

// MARK: - Card de GRANDE ÁREA (tile colorido + label; ~metade de baixo do caduceu)

private struct PlacaDeArea: View {
    let area: AreaBancada
    let ativa: Bool
    let apagada: Bool
    let acao: () -> Void

    private let topo = Color(red: 0.137, green: 0.086, blue: 0.055)      // ds-allow: arte gamificada (mundo da trilha)
    private let base = Color(red: 0.070, green: 0.043, blue: 0.023)      // ds-allow: arte gamificada (mundo da trilha)
    private let ouroTexto = LinearGradient(
        colors: [Color(red: 0.95, green: 0.84, blue: 0.58),              // ds-allow: arte gamificada (mundo da trilha)
                 Color(red: 0.80, green: 0.62, blue: 0.29)],             // ds-allow: arte gamificada (mundo da trilha)
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        Button(action: acao) {
            VStack(spacing: 5) {
                tile
                Text(area.nome)
                    .font(.system(size: 10.5, weight: .semibold, design: .serif))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(ouroTexto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 4)
            }
            .frame(width: 74, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)  // ds-allow: bancada de design da Jornada (preview-only, #if DEBUG)
                    .fill(
                        LinearGradient(colors: [topo, base], startPoint: .top, endPoint: .bottom)
                        .shadow(.inner(color: Color(red: 1.0, green: 0.87, blue: 0.63).opacity(0.13), radius: 0, y: 1.5))  // ds-allow: arte gamificada (mundo da trilha)
                        .shadow(.inner(color: .black.opacity(0.55), radius: 4, y: -3))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)  // ds-allow: bancada de design da Jornada (preview-only, #if DEBUG)
                    .strokeBorder(
                        LinearGradient(
                            colors: [TrailWorld.fireflyGold.opacity(ativa ? 0.95 : 0.30),
                                     TrailWorld.fireflyGold.opacity(ativa ? 0.6 : 0.08)],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: ativa ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 5, y: 4)
            .shadow(color: TrailWorld.fireflyGold.opacity(ativa ? 0.28 : 0), radius: 9)
            .scaleEffect(ativa ? 1.06 : 1)
            .opacity(apagada ? 0.55 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("area_card_\(area.slug)")
        .accessibilityAddTraits(ativa ? .isSelected : [])
    }

    private var tile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)  // ds-allow: bancada de design da Jornada (preview-only, #if DEBUG)
                .fill(
                    LinearGradient(colors: [area.corTopo, area.corBase],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    .shadow(.inner(color: .white.opacity(0.35), radius: 0, y: 1))
                    .shadow(.inner(color: .black.opacity(0.3), radius: 2, y: -1.5))
                )
                .frame(width: 38, height: 38)
                .shadow(color: area.corBase.opacity(ativa ? 0.65 : 0.4), radius: 6, y: 2)

            if let simbolo = area.simbolo {
                Image(systemName: simbolo)
                    .font(.system(size: 17, weight: .bold))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            } else if let glifo = area.glifo {
                Text(glifo)
                    .font(.system(size: 21, weight: .heavy))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            }
        }
        .padding(.top, 7)
    }
}

// MARK: - Card de DISCIPLINA (órgão colorido + anel de progresso + label)

private struct PlacaDeDisciplina: View {
    let disciplina: DisciplinaBancada
    let ativa: Bool
    let apagada: Bool
    let acao: () -> Void

    private let topo = Color(red: 0.137, green: 0.086, blue: 0.055)      // ds-allow: arte gamificada (mundo da trilha)
    private let base = Color(red: 0.070, green: 0.043, blue: 0.023)      // ds-allow: arte gamificada (mundo da trilha)
    private let ouroTexto = LinearGradient(
        colors: [Color(red: 0.95, green: 0.84, blue: 0.58),              // ds-allow: arte gamificada (mundo da trilha)
                 Color(red: 0.80, green: 0.62, blue: 0.29)],             // ds-allow: arte gamificada (mundo da trilha)
        startPoint: .top, endPoint: .bottom)
    private let ouroAnel = Color(red: 0.93, green: 0.78, blue: 0.42)     // ds-allow: arte gamificada (mundo da trilha)

    var body: some View {
        Button(action: acao) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [.black.opacity(0.5), .black.opacity(0.22), .clear],
                            center: .center, startRadius: 3, endRadius: 30))
                        .frame(width: 56, height: 56)
                    OrgaoIcone(orgao: disciplina.orgao)
                        .frame(width: 42, height: 42)
                        .shadow(color: disciplina.orgao.corGlow.opacity(ativa ? 0.6 : 0.38), radius: 7)
                }
                .padding(.top, 9)

                anelDeProgresso

                Text(disciplina.nome)
                    .font(.system(size: 11, weight: .semibold, design: .serif))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(ouroTexto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 5)

                Spacer(minLength: 0)
            }
            .frame(width: 86, height: 118)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: bancada de design da Jornada (preview-only, #if DEBUG)
                    .fill(
                        LinearGradient(colors: [topo, base], startPoint: .top, endPoint: .bottom)
                        .shadow(.inner(color: Color(red: 1.0, green: 0.87, blue: 0.63).opacity(0.13), radius: 0, y: 1.5))  // ds-allow: arte gamificada (mundo da trilha)
                        .shadow(.inner(color: .black.opacity(0.55), radius: 4, y: -3))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)  // ds-allow: bancada de design da Jornada (preview-only, #if DEBUG)
                    .strokeBorder(
                        LinearGradient(
                            colors: [TrailWorld.fireflyGold.opacity(ativa ? 0.95 : 0.30),
                                     TrailWorld.fireflyGold.opacity(ativa ? 0.6 : 0.08)],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: ativa ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 5, y: 4)
            .shadow(color: TrailWorld.fireflyGold.opacity(ativa ? 0.28 : 0), radius: 9)
            .scaleEffect(ativa ? 1.06 : 1)
            .opacity(apagada ? 0.55 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("disciplina_card_\(disciplina.slug)")
        .accessibilityAddTraits(ativa ? .isSelected : [])
    }

    /// Anel dourado com o % dentro — o "progress ring" da referência,
    /// falado na língua da madeira.
    private var anelDeProgresso: some View {
        ZStack {
            Circle()
                .stroke(.black.opacity(0.5), lineWidth: 3)
            Circle()
                .trim(from: 0, to: disciplina.progresso)
                .stroke(ouroAnel, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: ouroAnel.opacity(0.6), radius: 2)
            Text(verbatim: "\(Int(disciplina.progresso * 100))")
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(ouroTexto)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Caduceu (Canvas, coords lógicas 120×210)

struct CaduceuMiniArte: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 120, size.height / 210)
            ctx.translateBy(x: (size.width - 120 * s) / 2,
                            y: (size.height - 210 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            desenhar(&ctx)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private let contorno = Color(red: 0.14, green: 0.08, blue: 0.02)     // ds-allow: arte gamificada (mundo da trilha)
    private let brilho = Color(red: 1.0, green: 0.96, blue: 0.84)        // ds-allow: arte gamificada (mundo da trilha)

    private var ouroFrente: Gradient {
        Gradient(stops: [
            .init(color: Color(red: 0.93, green: 0.82, blue: 0.54), location: 0),    // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.75, green: 0.56, blue: 0.24), location: 0.5),  // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.38, green: 0.24, blue: 0.06), location: 1)])   // ds-allow: arte gamificada (mundo da trilha)
    }
    private var ouroTras: Gradient {
        Gradient(stops: [
            .init(color: Color(red: 0.58, green: 0.42, blue: 0.18), location: 0),    // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.28, green: 0.17, blue: 0.04), location: 1)])   // ds-allow: arte gamificada (mundo da trilha)
    }

    private func cubica(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p3: CGPoint) -> Path {
        var p = Path()
        p.move(to: p0)
        p.addCurve(to: p3, control1: c1, control2: c2)
        return p
    }

    private func trecho(_ ctx: inout GraphicsContext, _ p: Path,
                        yMin: CGFloat, yMax: CGFloat, w: CGFloat, frente: Bool) {
        ctx.stroke(p, with: .color(contorno),
                   style: StrokeStyle(lineWidth: w + 2.5, lineCap: .round))
        ctx.stroke(p, with: .linearGradient(frente ? ouroFrente : ouroTras,
                                            startPoint: CGPoint(x: 0, y: yMin - 12),
                                            endPoint: CGPoint(x: 0, y: yMax)),
                   style: StrokeStyle(lineWidth: w, lineCap: .round))
        ctx.stroke(p, with: .color(.black.opacity(0.15)),
                   style: StrokeStyle(lineWidth: max(1.5, w - 3), lineCap: .butt, dash: [1.8, 3.6]))
    }

    private func desenhar(_ ctx: inout GraphicsContext) {
        // cauda atrás → arcos de trás → haste+orbe → cauda frente → arcos da
        // frente → pescoço → cabeça
        let caudaTras = cubica(.init(x: 34, y: 168), .init(x: 34, y: 180),
                               .init(x: 48, y: 186), .init(x: 62, y: 187))
        trecho(&ctx, caudaTras, yMin: 168, yMax: 188, w: 5, frente: false)

        let tras = [
            (cubica(.init(x: 86, y: 148), .init(x: 86, y: 135), .init(x: 34, y: 141), .init(x: 34, y: 128)), CGFloat(128), CGFloat(148)),
            (cubica(.init(x: 86, y: 108), .init(x: 86, y: 95), .init(x: 34, y: 101), .init(x: 34, y: 88)), CGFloat(88), CGFloat(108)),
        ]
        for (p, a, b) in tras { trecho(&ctx, p, yMin: a, yMax: b, w: 7, frente: false) }

        // haste + ponta + orbe
        let ouroHaste = Gradient(stops: [
            .init(color: Color(red: 0.43, green: 0.29, blue: 0.08), location: 0),    // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.96, green: 0.86, blue: 0.57), location: 0.34), // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.78, green: 0.58, blue: 0.24), location: 0.58), // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.31, green: 0.19, blue: 0.04), location: 1)])   // ds-allow: arte gamificada (mundo da trilha)
        let hasteShading = GraphicsContext.Shading.linearGradient(
            ouroHaste, startPoint: CGPoint(x: 55, y: 0), endPoint: CGPoint(x: 65, y: 0))

        let haste = Path(roundedRect: CGRect(x: 55, y: 42, width: 10, height: 152), cornerRadius: 5)
        ctx.stroke(haste, with: .color(contorno), lineWidth: 1.6)
        ctx.fill(haste, with: hasteShading)
        var ponta = Path()
        ponta.move(to: .init(x: 55, y: 192)); ponta.addLine(to: .init(x: 65, y: 192))
        ponta.addLine(to: .init(x: 60, y: 208)); ponta.closeSubpath()
        ctx.fill(ponta, with: hasteShading)

        let orbe = Path(ellipseIn: CGRect(x: 43, y: 8, width: 34, height: 34))
        ctx.stroke(orbe, with: .color(contorno), lineWidth: 1.6)
        ctx.fill(orbe, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.99, green: 0.95, blue: 0.78), location: 0),    // ds-allow: arte gamificada (mundo da trilha)
                .init(color: Color(red: 0.89, green: 0.70, blue: 0.36), location: 0.5),  // ds-allow: arte gamificada (mundo da trilha)
                .init(color: Color(red: 0.42, green: 0.27, blue: 0.06), location: 1)]),  // ds-allow: arte gamificada (mundo da trilha)
            center: CGPoint(x: 54, y: 19), startRadius: 1, endRadius: 26))
        ctx.fill(Path(ellipseIn: CGRect(x: 50, y: 14, width: 6, height: 4.5)),
                 with: .color(brilho.opacity(0.85)))

        let caudaFrente = cubica(.init(x: 62, y: 187), .init(x: 74, y: 188),
                                 .init(x: 82, y: 184), .init(x: 86, y: 177))
        trecho(&ctx, caudaFrente, yMin: 174, yMax: 188, w: 4.5, frente: true)

        let frente = [
            (cubica(.init(x: 34, y: 168), .init(x: 34, y: 155), .init(x: 86, y: 161), .init(x: 86, y: 148)), CGFloat(148), CGFloat(168)),
            (cubica(.init(x: 34, y: 128), .init(x: 34, y: 115), .init(x: 86, y: 121), .init(x: 86, y: 108)), CGFloat(108), CGFloat(128)),
        ]
        for (p, a, b) in frente { trecho(&ctx, p, yMin: a, yMax: b, w: 9, frente: true) }

        let pescoco = cubica(.init(x: 34, y: 88), .init(x: 34, y: 70),
                             .init(x: 74, y: 76), .init(x: 74, y: 56))
        trecho(&ctx, pescoco, yMin: 56, yMax: 88, w: 7.5, frente: true)

        // cabeça pequena de perfil, olhando pra direita
        var cab = Path()
        cab.move(to: .init(x: 72, y: 58))
        cab.addCurve(to: .init(x: 79, y: 44), control1: .init(x: 70, y: 51), control2: .init(x: 73, y: 46))
        cab.addCurve(to: .init(x: 96, y: 48), control1: .init(x: 86, y: 41), control2: .init(x: 93, y: 44))
        cab.addCurve(to: .init(x: 94, y: 54), control1: .init(x: 98, y: 50), control2: .init(x: 97, y: 53))
        cab.addCurve(to: .init(x: 72, y: 58), control1: .init(x: 86, y: 57), control2: .init(x: 77, y: 60))
        cab.closeSubpath()
        ctx.stroke(cab, with: .color(contorno), lineWidth: 1.8)
        ctx.fill(cab, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.89, green: 0.77, blue: 0.49), location: 0),   // ds-allow: arte gamificada (mundo da trilha)
                .init(color: Color(red: 0.62, green: 0.44, blue: 0.16), location: 0.6), // ds-allow: arte gamificada (mundo da trilha)
                .init(color: Color(red: 0.28, green: 0.17, blue: 0.04), location: 1)]), // ds-allow: arte gamificada (mundo da trilha)
            center: CGPoint(x: 82, y: 48), startRadius: 1, endRadius: 16))
        ctx.fill(Path(ellipseIn: CGRect(x: 84.6, y: 46.4, width: 3.2, height: 3.2)),
                 with: .color(Color(red: 0.11, green: 0.06, blue: 0.02)))  // ds-allow: arte gamificada (mundo da trilha)
    }
}

// MARK: - Órgãos coloridos (portados do claudereference.html, Canvas 120×120)

struct OrgaoIcone: View {
    enum Orgao {
        case coracao, pulmao, rim, tireoide, estomago, virus

        var corGlow: Color {
            switch self {
            case .coracao:  return Color(red: 0.92, green: 0.31, blue: 0.27)  // ds-allow: arte gamificada (mundo da trilha)
            case .pulmao:   return Color(red: 0.27, green: 0.59, blue: 0.94)  // ds-allow: arte gamificada (mundo da trilha)
            case .rim:      return Color(red: 0.43, green: 0.75, blue: 0.27)  // ds-allow: arte gamificada (mundo da trilha)
            case .tireoide: return Color(red: 0.63, green: 0.39, blue: 0.90)  // ds-allow: arte gamificada (mundo da trilha)
            case .estomago: return Color(red: 0.94, green: 0.47, blue: 0.59)  // ds-allow: arte gamificada (mundo da trilha)
            case .virus:    return Color(red: 0.96, green: 0.55, blue: 0.25)  // ds-allow: arte gamificada (mundo da trilha)
            }
        }
    }

    let orgao: Orgao

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 120, size.height / 120)
            ctx.translateBy(x: (size.width - 120 * s) / 2,
                            y: (size.height - 120 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            switch orgao {
            case .coracao: coracao(&ctx)
            case .pulmao: pulmao(&ctx)
            case .rim: rim(&ctx)
            case .tireoide: tireoide(&ctx)
            case .estomago: estomago(&ctx)
            case .virus: virus(&ctx)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cubica(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p3: CGPoint) -> Path {
        var p = Path()
        p.move(to: p0)
        p.addCurve(to: p3, control1: c1, control2: c2)
        return p
    }

    private func rotacao(_ graus: CGFloat, cx: CGFloat, cy: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: graus * .pi / 180)
            .translatedBy(x: -cx, y: -cy)
    }

    // ─── Coração (rubi + linha de ECG dourada) ───
    private func coracao(_ ctx: inout GraphicsContext) {
        var p = Path()
        p.move(to: .init(x: 60, y: 104))
        p.addCurve(to: .init(x: 12, y: 40), control1: .init(x: 34, y: 84), control2: .init(x: 12, y: 63))
        p.addCurve(to: .init(x: 41, y: 11), control1: .init(x: 12, y: 22), control2: .init(x: 25, y: 11))
        p.addCurve(to: .init(x: 60, y: 26), control1: .init(x: 51, y: 11), control2: .init(x: 58, y: 17))
        p.addCurve(to: .init(x: 79, y: 11), control1: .init(x: 62, y: 17), control2: .init(x: 69, y: 11))
        p.addCurve(to: .init(x: 108, y: 40), control1: .init(x: 95, y: 11), control2: .init(x: 108, y: 22))
        p.addCurve(to: .init(x: 60, y: 104), control1: .init(x: 108, y: 63), control2: .init(x: 86, y: 84))
        p.closeSubpath()
        ctx.fill(p, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.96, green: 0.49, blue: 0.45), location: 0),    // ds-allow: arte gamificada (mundo da trilha)
                .init(color: Color(red: 0.81, green: 0.19, blue: 0.22), location: 0.45), // ds-allow: arte gamificada (mundo da trilha)
                .init(color: Color(red: 0.55, green: 0.07, blue: 0.10), location: 0.78), // ds-allow: arte gamificada (mundo da trilha)
                .init(color: Color(red: 0.36, green: 0.05, blue: 0.06), location: 1)]),  // ds-allow: arte gamificada (mundo da trilha)
            center: CGPoint(x: 48, y: 38), startRadius: 4, endRadius: 78))

        var gloss = Path()
        gloss.addEllipse(in: CGRect(x: 26, y: 22, width: 24, height: 16))
        ctx.fill(gloss.applying(rotacao(-22, cx: 38, cy: 30)),
                 with: .color(Color(red: 1.0, green: 0.87, blue: 0.85).opacity(0.32)))  // ds-allow: arte gamificada (mundo da trilha)

        var ecg = Path()
        ecg.move(to: .init(x: 14, y: 57))
        ecg.addLine(to: .init(x: 38, y: 57))
        ecg.addLine(to: .init(x: 46, y: 42))
        ecg.addLine(to: .init(x: 57, y: 74))
        ecg.addLine(to: .init(x: 66, y: 49))
        ecg.addLine(to: .init(x: 71, y: 57))
        ecg.addLine(to: .init(x: 106, y: 57))
        let ouro = Color(red: 0.96, green: 0.81, blue: 0.46)  // ds-allow: arte gamificada (mundo da trilha)
        ctx.drawLayer { camada in
            camada.addFilter(.blur(radius: 2.2))
            camada.stroke(ecg, with: .color(ouro.opacity(0.85)),
                          style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        ctx.stroke(ecg, with: .color(ouro),
                   style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round))
    }

    // ─── Pulmão (azul, traqueia + dois lobos) ───
    private func pulmao(_ ctx: inout GraphicsContext) {
        let grad = Gradient(stops: [
            .init(color: Color(red: 0.43, green: 0.76, blue: 0.97), location: 0),    // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.16, green: 0.44, blue: 0.74), location: 0.55), // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.08, green: 0.24, blue: 0.45), location: 1)])   // ds-allow: arte gamificada (mundo da trilha)
        func shading(_ yMin: CGFloat, _ yMax: CGFloat) -> GraphicsContext.Shading {
            .linearGradient(grad, startPoint: CGPoint(x: 0, y: yMin), endPoint: CGPoint(x: 0, y: yMax))
        }

        var traq = Path()
        traq.move(to: .init(x: 60, y: 10)); traq.addLine(to: .init(x: 60, y: 32))
        ctx.stroke(traq, with: shading(10, 47), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        ctx.stroke(cubica(.init(x: 60, y: 32), .init(x: 60, y: 40), .init(x: 54, y: 43), .init(x: 49, y: 47)),
                   with: shading(30, 48), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        ctx.stroke(cubica(.init(x: 60, y: 32), .init(x: 60, y: 40), .init(x: 66, y: 43), .init(x: 71, y: 47)),
                   with: shading(30, 48), style: StrokeStyle(lineWidth: 8, lineCap: .round))

        var le = Path()
        le.move(to: .init(x: 50, y: 42))
        le.addCurve(to: .init(x: 20, y: 64), control1: .init(x: 38, y: 36), control2: .init(x: 24, y: 46))
        le.addCurve(to: .init(x: 38, y: 104), control1: .init(x: 16, y: 83), control2: .init(x: 24, y: 100))
        le.addCurve(to: .init(x: 53, y: 86), control1: .init(x: 48, y: 107), control2: .init(x: 53, y: 99))
        le.addLine(to: .init(x: 53, y: 52))
        le.addCurve(to: .init(x: 50, y: 42), control1: .init(x: 53, y: 46), control2: .init(x: 52, y: 44))
        le.closeSubpath()
        ctx.fill(le, with: shading(36, 107))

        var ld = Path()
        ld.move(to: .init(x: 70, y: 42))
        ld.addCurve(to: .init(x: 100, y: 64), control1: .init(x: 82, y: 36), control2: .init(x: 96, y: 46))
        ld.addCurve(to: .init(x: 82, y: 104), control1: .init(x: 104, y: 83), control2: .init(x: 96, y: 100))
        ld.addCurve(to: .init(x: 67, y: 86), control1: .init(x: 72, y: 107), control2: .init(x: 67, y: 99))
        ld.addLine(to: .init(x: 67, y: 52))
        ld.addCurve(to: .init(x: 70, y: 42), control1: .init(x: 67, y: 46), control2: .init(x: 68, y: 44))
        ld.closeSubpath()
        ctx.fill(ld, with: shading(36, 107))

        let veia = Color(red: 0.76, green: 0.90, blue: 1.0).opacity(0.42)  // ds-allow: arte gamificada (mundo da trilha)
        ctx.stroke(cubica(.init(x: 40, y: 56), .init(x: 36, y: 66), .init(x: 36, y: 78), .init(x: 40, y: 92)),
                   with: .color(veia), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        ctx.stroke(cubica(.init(x: 80, y: 56), .init(x: 84, y: 66), .init(x: 84, y: 78), .init(x: 80, y: 92)),
                   with: .color(veia), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

        var gloss = Path()
        gloss.addEllipse(in: CGRect(x: 24, y: 44, width: 16, height: 26))
        ctx.fill(gloss.applying(rotacao(12, cx: 32, cy: 57)),
                 with: .color(Color(red: 0.92, green: 0.98, blue: 1.0).opacity(0.26)))  // ds-allow: arte gamificada (mundo da trilha)
    }

    // ─── Rim (verde, dois feijões + ureteres) ───
    private func rim(_ ctx: inout GraphicsContext) {
        let grad = Gradient(stops: [
            .init(color: Color(red: 0.60, green: 0.84, blue: 0.37), location: 0),    // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.25, green: 0.52, blue: 0.16), location: 0.55), // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.11, green: 0.30, blue: 0.07), location: 1)])   // ds-allow: arte gamificada (mundo da trilha)
        let shading = GraphicsContext.Shading.linearGradient(
            grad, startPoint: CGPoint(x: 0, y: 22), endPoint: CGPoint(x: 0, y: 98))

        ctx.stroke(cubica(.init(x: 49, y: 62), .init(x: 54, y: 64), .init(x: 56, y: 70), .init(x: 56, y: 78)),
                   with: shading, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        var u1 = Path(); u1.move(to: .init(x: 56, y: 78)); u1.addLine(to: .init(x: 56, y: 98))
        ctx.stroke(u1, with: shading, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        ctx.stroke(cubica(.init(x: 71, y: 62), .init(x: 66, y: 64), .init(x: 64, y: 70), .init(x: 64, y: 78)),
                   with: shading, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        var u2 = Path(); u2.move(to: .init(x: 64, y: 78)); u2.addLine(to: .init(x: 64, y: 98))
        ctx.stroke(u2, with: shading, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))

        var re = Path()
        re.move(to: .init(x: 46, y: 24))
        re.addCurve(to: .init(x: 18, y: 59), control1: .init(x: 30, y: 24), control2: .init(x: 18, y: 40))
        re.addCurve(to: .init(x: 43, y: 91), control1: .init(x: 18, y: 78), control2: .init(x: 29, y: 92))
        re.addCurve(to: .init(x: 50, y: 77), control1: .init(x: 51, y: 90), control2: .init(x: 54, y: 84))
        re.addCurve(to: .init(x: 50, y: 43), control1: .init(x: 44, y: 68), control2: .init(x: 44, y: 52))
        re.addCurve(to: .init(x: 46, y: 24), control1: .init(x: 54, y: 36), control2: .init(x: 53, y: 24))
        re.closeSubpath()
        ctx.fill(re, with: shading)

        var rd = Path()
        rd.move(to: .init(x: 74, y: 24))
        rd.addCurve(to: .init(x: 102, y: 59), control1: .init(x: 90, y: 24), control2: .init(x: 102, y: 40))
        rd.addCurve(to: .init(x: 77, y: 91), control1: .init(x: 102, y: 78), control2: .init(x: 91, y: 92))
        rd.addCurve(to: .init(x: 70, y: 77), control1: .init(x: 69, y: 90), control2: .init(x: 66, y: 84))
        rd.addCurve(to: .init(x: 70, y: 43), control1: .init(x: 76, y: 68), control2: .init(x: 76, y: 52))
        rd.addCurve(to: .init(x: 74, y: 24), control1: .init(x: 66, y: 36), control2: .init(x: 67, y: 24))
        rd.closeSubpath()
        ctx.fill(rd, with: shading)

        let veia = Color(red: 0.87, green: 1.0, blue: 0.76).opacity(0.4)  // ds-allow: arte gamificada (mundo da trilha)
        ctx.stroke(cubica(.init(x: 33, y: 36), .init(x: 28, y: 47), .init(x: 27, y: 62), .init(x: 32, y: 76)),
                   with: .color(veia), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
        ctx.stroke(cubica(.init(x: 87, y: 36), .init(x: 92, y: 47), .init(x: 93, y: 62), .init(x: 88, y: 76)),
                   with: .color(veia), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))

        var gloss = Path()
        gloss.addEllipse(in: CGRect(x: 23, y: 27, width: 14, height: 20))
        ctx.fill(gloss.applying(rotacao(18, cx: 30, cy: 37)),
                 with: .color(Color(red: 0.93, green: 1.0, blue: 0.88).opacity(0.28)))  // ds-allow: arte gamificada (mundo da trilha)
    }

    // ─── Tireoide (roxa, borboleta com poros) ───
    private func tireoide(_ ctx: inout GraphicsContext) {
        let grad = Gradient(stops: [
            .init(color: Color(red: 0.74, green: 0.50, blue: 0.95), location: 0),    // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.48, green: 0.25, blue: 0.75), location: 0.55), // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.29, green: 0.13, blue: 0.47), location: 1)])   // ds-allow: arte gamificada (mundo da trilha)
        let shading = GraphicsContext.Shading.linearGradient(
            grad, startPoint: CGPoint(x: 0, y: 22), endPoint: CGPoint(x: 0, y: 98))

        let lobEsq = Path(roundedRect: CGRect(x: 25, y: 22, width: 28, height: 76), cornerRadius: 14)
            .applying(rotacao(-9, cx: 39, cy: 60))
        let lobDir = Path(roundedRect: CGRect(x: 67, y: 22, width: 28, height: 76), cornerRadius: 14)
            .applying(rotacao(9, cx: 81, cy: 60))
        let istmo = Path(roundedRect: CGRect(x: 46, y: 54, width: 28, height: 16), cornerRadius: 8)
        ctx.fill(lobEsq, with: shading)
        ctx.fill(lobDir, with: shading)
        ctx.fill(istmo, with: shading)

        let poroEscuro = Color(red: 0.14, green: 0.03, blue: 0.24).opacity(0.42)   // ds-allow: arte gamificada (mundo da trilha)
        let poroClaro = Color(red: 0.92, green: 0.84, blue: 1.0).opacity(0.28)     // ds-allow: arte gamificada (mundo da trilha)
        let poros: [(CGFloat, CGFloat, CGFloat)] = [
            (34, 42, 2.6), (39, 58, 2.2), (31, 70, 2.4), (38, 84, 2.0),
            (86, 42, 2.6), (81, 58, 2.2), (89, 70, 2.4), (82, 84, 2.0), (60, 62, 1.9),
        ]
        for (x, y, r) in poros {
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(poroEscuro))
            ctx.fill(Path(ellipseIn: CGRect(x: x - r + 1, y: y - r + 1, width: r, height: r)),
                     with: .color(poroClaro))
        }

        var gloss = Path()
        gloss.addEllipse(in: CGRect(x: 28, y: 26, width: 12, height: 22))
        ctx.fill(gloss.applying(rotacao(-9, cx: 34, cy: 37)),
                 with: .color(Color(red: 0.95, green: 0.89, blue: 1.0).opacity(0.3)))  // ds-allow: arte gamificada (mundo da trilha)
    }

    // ─── Estômago (rosa, esôfago + corpo + duodeno) ───
    private func estomago(_ ctx: inout GraphicsContext) {
        let grad = Gradient(stops: [
            .init(color: Color(red: 0.97, green: 0.64, blue: 0.70), location: 0),    // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.79, green: 0.36, blue: 0.45), location: 0.55), // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.58, green: 0.22, blue: 0.31), location: 1)])   // ds-allow: arte gamificada (mundo da trilha)
        func shading(_ yMin: CGFloat, _ yMax: CGFloat) -> GraphicsContext.Shading {
            .linearGradient(grad, startPoint: CGPoint(x: 0, y: yMin), endPoint: CGPoint(x: 0, y: yMax))
        }

        var eso = Path()
        eso.move(to: .init(x: 44, y: 6)); eso.addLine(to: .init(x: 44, y: 26))
        eso.addCurve(to: .init(x: 55, y: 42), control1: .init(x: 44, y: 34), control2: .init(x: 48, y: 39))
        ctx.stroke(eso, with: shading(6, 46), style: StrokeStyle(lineWidth: 13, lineCap: .round))

        var corpo = Path()
        corpo.move(to: .init(x: 30, y: 70))
        corpo.addCurve(to: .init(x: 58, y: 43), control1: .init(x: 24, y: 52), control2: .init(x: 38, y: 40))
        corpo.addCurve(to: .init(x: 94, y: 80), control1: .init(x: 82, y: 47), control2: .init(x: 98, y: 62))
        corpo.addCurve(to: .init(x: 50, y: 102), control1: .init(x: 90, y: 98), control2: .init(x: 68, y: 108))
        corpo.addCurve(to: .init(x: 30, y: 70), control1: .init(x: 36, y: 97), control2: .init(x: 32, y: 86))
        corpo.closeSubpath()
        ctx.fill(corpo, with: shading(40, 108))

        var duo = Path()
        duo.move(to: .init(x: 34, y: 92))
        duo.addCurve(to: .init(x: 27, y: 113), control1: .init(x: 26, y: 98), control2: .init(x: 23, y: 106))
        ctx.stroke(duo, with: shading(88, 114), style: StrokeStyle(lineWidth: 11, lineCap: .round))

        let ruga = Color(red: 0.42, green: 0.10, blue: 0.19).opacity(0.32)  // ds-allow: arte gamificada (mundo da trilha)
        ctx.stroke(cubica(.init(x: 48, y: 90), .init(x: 58, y: 95), .init(x: 72, y: 94), .init(x: 82, y: 86)),
                   with: .color(ruga), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        ctx.stroke(cubica(.init(x: 44, y: 80), .init(x: 56, y: 87), .init(x: 74, y: 86), .init(x: 86, y: 76)),
                   with: .color(ruga), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

        var gloss = Path()
        gloss.addEllipse(in: CGRect(x: 40, y: 50, width: 28, height: 16))
        ctx.fill(gloss.applying(rotacao(-14, cx: 54, cy: 58)),
                 with: .color(Color(red: 1.0, green: 0.93, blue: 0.95).opacity(0.34)))  // ds-allow: arte gamificada (mundo da trilha)
    }

    // ─── Vírus (laranja, esfera com espículas — Infectologia) ───
    private func virus(_ ctx: inout GraphicsContext) {
        let centro = CGPoint(x: 60, y: 60)
        let raio: CGFloat = 30
        let corEspicula = Color(red: 0.85, green: 0.38, blue: 0.12)  // ds-allow: arte gamificada (mundo da trilha)

        for i in 0..<12 {
            let ang = CGFloat(i) * (.pi * 2 / 12)
            let d = CGPoint(x: cos(ang), y: sin(ang))
            var haste = Path()
            haste.move(to: .init(x: centro.x + d.x * raio, y: centro.y + d.y * raio))
            haste.addLine(to: .init(x: centro.x + d.x * (raio + 14), y: centro.y + d.y * (raio + 14)))
            ctx.stroke(haste, with: .color(corEspicula),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round))
            let ponta = CGPoint(x: centro.x + d.x * (raio + 17), y: centro.y + d.y * (raio + 17))
            ctx.fill(Path(ellipseIn: CGRect(x: ponta.x - 4, y: ponta.y - 4, width: 8, height: 8)),
                     with: .color(corEspicula))
        }

        ctx.fill(Path(ellipseIn: CGRect(x: centro.x - raio, y: centro.y - raio,
                                        width: raio * 2, height: raio * 2)),
                 with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 1.0, green: 0.72, blue: 0.38), location: 0),    // ds-allow: arte gamificada (mundo da trilha)
                        .init(color: Color(red: 0.93, green: 0.48, blue: 0.16), location: 0.55), // ds-allow: arte gamificada (mundo da trilha)
                        .init(color: Color(red: 0.62, green: 0.24, blue: 0.05), location: 1)]),  // ds-allow: arte gamificada (mundo da trilha)
                    center: CGPoint(x: 50, y: 48), startRadius: 3, endRadius: 42))

        // poros da cápsula
        let poro = Color(red: 0.45, green: 0.15, blue: 0.02).opacity(0.5)  // ds-allow: arte gamificada (mundo da trilha)
        let poros: [(CGFloat, CGFloat, CGFloat)] = [
            (50, 52, 3.4), (68, 46, 2.6), (60, 68, 3.0), (46, 68, 2.2), (72, 64, 2.4),
        ]
        for (x, y, r) in poros {
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(poro))
        }

        var gloss = Path()
        gloss.addEllipse(in: CGRect(x: 44, y: 38, width: 18, height: 12))
        ctx.fill(gloss.applying(rotacao(-18, cx: 53, cy: 44)),
                 with: .color(Color(red: 1.0, green: 0.93, blue: 0.85).opacity(0.4)))  // ds-allow: arte gamificada (mundo da trilha)
    }
}

// MARK: - Hot reload (InjectionNext)

/// Re-renderiza a tela quando o InjectionNext injeta um arquivo salvo.
final class ObservadorDeInjecao: ObservableObject {
    @Published var tick = 0
    private var observador: NSObjectProtocol?

    init() {
        #if DEBUG
        observador = NotificationCenter.default.addObserver(
            forName: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.tick += 1
        }
        #endif
    }

    deinit {
        if let observador { NotificationCenter.default.removeObserver(observador) }
    }
}

#Preview {
    JornadaCaduceuScreen()
}
