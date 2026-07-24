import SwiftUI

// MARK: - TrailTopPlaca — a placa de madeira do topo da Jornada
//
// Substitui as pílulas escuras + o círculo cinza do menu. O topo falava TRÊS
// línguas ao mesmo tempo (emblema de ouro polido do app, cápsulas translúcidas
// genéricas, círculo de sistema); agora fala uma só (Rafael 2026-07-23).
//
// DESIGN.md §5 manda: peça que vive DENTRO do mundo da trilha usa TrailWorld e
// a física de luz de cima-esquerda — não o glass gold do resto do app. Mesmo
// vocabulário do TrailMissionSign: tábua com bisel iluminado no topo, veio,
// espessura e sombra no chão.
//
// Três detalhes que o protótipo no navegador provou (e que eu tinha errado):
//  1. o número tem que falar a língua do ícone ao lado — brasa no fogo, ouro na
//     moeda. Antes os dois eram creme e não pertenciam a nada;
//  2. numeral ARREDONDADA (.rounded) combina com a madeira; a de sistema tem
//     terminação reta e briga com a forma;
//  3. `Text("\(Int)")` passa pelo formatador de local e vira "3.049" — nesse
//     tamanho o ponto lê como vírgula decimal. Por isso `Text(verbatim:)`.

struct TrailTopPlaca: View {
    /// Nome do filtro ativo ("Tudo" quando não há área/disciplina escolhida).
    let filtroNome: String
    /// SF Symbol do filtro. Nil = estado "Tudo".
    let filtroSimbolo: String?
    let diasSeguidos: Int
    let moedas: Int
    /// Seção atual do aluno para o chip da topnav (ex.: "Seção 1 · Calouro"),
    /// ao lado da maleta. Herdou o lugar da inscrição que ficava gravada na
    /// muralha — lá o vidro glass borrava o texto do mapa que passava atrás
    /// (Rafael 2026-07-24). `tierNome` vazio = não mostra o chip.
    var tierNumero: Int = 1
    var tierNome: String = ""
    var tierCor: Color = .white

    var aoTocarOfensiva: () -> Void
    var aoTocarMoedas: () -> Void
    var aoTocarMenu: () -> Void
    /// Toque numa das 6 grandes áreas da gaveta (nil = "medicina inteira").
    var aoSelecionarArea: (GrandeArea?) -> Void = { _ in }
    /// Disciplinas reais por área (slug → lista). Propriedade (não closure): ao
    /// chegar do backend, a barra re-renderiza e a seção preenche sozinha.
    var disciplinasPorArea: [String: [DisciplinaDaArea]] = [:]
    /// Toque numa disciplina da seção aberta.
    var aoSelecionarDisciplina: (DisciplinaDaArea) -> Void = { _ in }

    private let altura: CGFloat = 48
    // hot reload: re-renderiza a barra ao injetar (InjectionNext). Sem isto o
    // SwiftUI não redesenha sozinho e a injeção "não pega".
    @StateObject private var injecao = ObservadorDeInjecao()

    // A gaveta das áreas desce ao tocar na maleta.
    @State private var gavetaAberta = false
    @State private var areaSelecionada: GrandeArea?
    // "Ver todas" (issue #95 item 10): folha com todas as disciplinas da área.
    @State private var verTodasArea: GrandeArea?

    // altura da fila de áreas (cards 10% menores + respiro)
    private let alturaAreas: CGFloat = 100
    // altura da seção de disciplinas (aparece quando há área selecionada)
    private let alturaDisc: CGFloat = 170
    private var alturaGaveta: CGFloat {
        alturaAreas + (areaSelecionada != nil ? alturaDisc : 0)
    }

    var body: some View {
        VStack(spacing: 4) {
            barraPrincipal
                .zIndex(2)   // a frente da cômoda: cobre o topo da gaveta
            gavetaContainer
                .zIndex(1)
        }
        .id(injecao.tick)   // hot reload
        .sheet(item: $verTodasArea) { area in
            verTodasSheet(area)
        }
    }

    /// "Ver todas" (issue #95 item 10): todas as disciplinas da área numa grade
    /// rolável (o horizontal só mostra ~7). Fundo escuro do mundo da trilha pros
    /// rótulos creme + pastilhas glossy lerem bem.
    @ViewBuilder
    private func verTodasSheet(_ area: GrandeArea) -> some View {
        let discs = disciplinasPorArea[area.rawValue] ?? []
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                          spacing: 20) {
                    ForEach(discs) { disc in
                        Button {
                            aoSelecionarDisciplina(disc)
                            verTodasArea = nil
                        } label: {
                            DisciplinaChip(disc: disc, cor: area.corAssinatura)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.11, green: 0.09, blue: 0.07).ignoresSafeArea())  // ds-allow: mundo da trilha
            .navigationTitle("Disciplinas de \(area.nomeCurto)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { verTodasArea = nil }
                        .font(.system(size: 15, weight: .semibold))  // ds-allow: arte gamificada
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// A gaveta REAL: cresce de cima pra baixo saindo de trás da barra, com
    /// clip — os cards são revelados como se a gaveta fosse puxada pra fora.
    private var gavetaContainer: some View {
        gavetaConteudo
            // "engolir/emergir da maleta" (issue #95 itens 8-9): o painel encolhe
            // + some em direção ao canto da maleta (topo-esquerda) ao fechar, e
            // brota de lá ao abrir. A âncora ~0.09 fica em cima da maleta.
            .scaleEffect(gavetaAberta ? 1 : 0.4, anchor: UnitPoint(x: 0.09, y: 0))
            .opacity(gavetaAberta ? 1 : 0)
            .frame(height: gavetaAberta ? alturaGaveta : 0, alignment: .top)
            .clipped()
            .offset(y: gavetaAberta ? 0 : -18)
            .animation(.spring(response: 0.52, dampingFraction: 0.80), value: gavetaAberta)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: areaSelecionada)
    }

    /// Dois andares: fila das 6 áreas + (quando há seleção) seção de disciplinas.
    private var gavetaConteudo: some View {
        VStack(spacing: 0) {
            gavetaAreas
            if let area = areaSelecionada {
                secaoDisciplinas(area)
            }
        }
        .frame(maxWidth: .infinity)
        .vidroLiquido()
        // puxador sutil de vidro na base — reforça "gaveta"
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(.white.opacity(0.30))
                .frame(width: 34, height: 3)
                .padding(.bottom, 4)
        }
    }

    private var barraPrincipal: some View {
        HStack(spacing: 11) {
            botaoFiltro
            if !tierNome.isEmpty { tierChip }
            divisor

            Button(action: aoTocarOfensiva) {
                HStack(spacing: 6) {
                    chama
                    numero("\(diasSeguidos)", cor: Self.brasa, sombra: Self.brasaSombra)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("trail_ofensiva")
            .accessibilityLabel("\(diasSeguidos) dias seguidos")

            Button(action: aoTocarMoedas) {
                HStack(spacing: 6) {
                    CoinIcon(size: 19)
                    numero("\(moedas)", cor: Self.ouro, sombra: Self.ouroSombra)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("trail_moedas")
            .accessibilityLabel("\(moedas) moedas")

            Spacer(minLength: 0)
            divisor
            botaoMenu
        }
        .padding(.horizontal, 12)
        .frame(height: altura)
        .vidroLiquido()
    }

    // MARK: Gaveta das 6 grandes áreas

    private var gavetaAreas: some View {
        HStack(spacing: 6) {
            ForEach(Array(GrandeArea.allCases.enumerated()), id: \.element) { idx, area in
                let sel = areaSelecionada == area
                VStack(spacing: 0) {
                    Button {
                        // toca a mesma = desmarca (volta pra "medicina inteira")
                        areaSelecionada = sel ? nil : area
                        aoSelecionarArea(areaSelecionada)
                    } label: {
                        AreaCardVita(area: area, selecionada: sel)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("jornada_area_\(area.rawValue)")
                    .devTag("Card de área: \(area.nome)")

                    // aba/seta estilo Duolingo: triângulo na cor da área,
                    // apontando pra baixo, ligando o card à seção que abre.
                    Triangulo()
                        .fill(area.corAssinatura)
                        .frame(width: 16, height: 8)
                        .opacity(sel ? 1 : 0)
                        .padding(.top, 3)
                }
                // emergem em sequência com leve overshoot; no fechar recolhem
                // juntos (delay 0) rumo à maleta. (issue #95 item 9)
                .scaleEffect(gavetaAberta ? 1 : 0.7, anchor: .top)
                .opacity(gavetaAberta ? 1 : 0)
                .animation(.spring(response: 0.42, dampingFraction: 0.66)
                            .delay(gavetaAberta ? Double(idx) * 0.045 : 0),
                           value: gavetaAberta)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .frame(height: alturaAreas, alignment: .top)
    }

    /// Seção que abre embaixo com as disciplinas reais da área selecionada.
    private func secaoDisciplinas(_ area: GrandeArea) -> some View {
        let discs = disciplinasPorArea[area.rawValue] ?? []
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Disciplinas de \(area.nomeCurto)")
                    .font(.system(size: 13, weight: .bold))  // ds-allow: arte gamificada
                    .foregroundStyle(Color(red: 0.95, green: 0.88, blue: 0.72))  // ds-allow: arte gamificada
                Spacer()
                Button {
                    verTodasArea = area
                } label: {
                    Text("Ver todas ›")
                        .font(.system(size: 11, weight: .semibold))  // ds-allow: arte gamificada
                        .foregroundStyle(area.corAssinatura.mais(0.15))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("jornada_ver_todas")
            }
            .padding(.horizontal, 14)

            if discs.isEmpty {
                Text("Nenhuma disciplina carregada ainda.")
                    .font(.system(size: 11))  // ds-allow: arte gamificada
                    .foregroundStyle(Color(red: 0.7, green: 0.63, blue: 0.5))  // ds-allow: arte gamificada
                    .padding(.horizontal, 14)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(discs) { disc in
                            Button { aoSelecionarDisciplina(disc) } label: {
                                DisciplinaChip(disc: disc, cor: area.corAssinatura)
                            }
                            .buttonStyle(.plain)
                            .devTag("Chip de disciplina: \(disc.nome)")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)   // respiro pras sombras da pastilha
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(height: alturaDisc, alignment: .top)
        // fio de luz separando a fila de áreas da seção
        .overlay(alignment: .top) {
            Rectangle().fill(TrailWorld.fireflyGold.opacity(0.14)).frame(height: 1)
        }
    }

    // MARK: Matéria da tábua

    private var tabua: some View {
        RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
            .fill(
                LinearGradient(colors: [TrailWorld.trunkTop, TrailWorld.trunkBottom],
                               startPoint: .top, endPoint: .bottom)
                // bisel iluminado no topo (fio de luz = peça sólida)
                .shadow(.inner(color: TrailWorld.fireflyWarm.opacity(0.34), radius: 0, y: 2))
                // recesso na base (a peça tem espessura)
                .shadow(.inner(color: .black.opacity(0.45), radius: 4, y: -3))
            )
            .overlay(veio)
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .strokeBorder(TrailWorld.fireflyGold.opacity(0.16), lineWidth: 1)
            )
            // espessura + sombra no chão (ancora a peça no mundo)
            .shadow(color: .black.opacity(0.35), radius: 0, y: 5)
            .shadow(color: .black.opacity(0.5), radius: 9, y: 10)
    }

    /// Veio da madeira: linhas finas na horizontal, quase imperceptíveis.
    /// `.transaction` desliga animação — peça estática não re-avalia por frame
    /// (mesma regra da Semi3DHouse; sem isso ela "respira" no scroll).
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

    // MARK: Peças

    private var botaoFiltro: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { gavetaAberta.toggle() }
        } label: {
            HStack(spacing: 6) {
                // Estado "Tudo" (medicina inteira) = maleta médica colorida; um
                // filtro de área/disciplina ativo troca pelo símbolo dela.
                // Estado "Tudo" (medicina inteira) = só a maleta, sem rótulo,
                // cobrindo bem o centro da coluna. Filtro de área ativo mostra
                // o símbolo dela + o nome.
                if let simbolo = filtroSimbolo {
                    Image(systemName: simbolo)
                        .font(.system(size: 17, weight: .semibold))  // ds-allow: arte gamificada (mundo da trilha)
                        .foregroundStyle(TrailWorld.fireflyWarm)
                    Text(filtroNome)
                        .font(.system(size: 12, weight: .bold))       // ds-allow: arte gamificada (mundo da trilha)
                        .foregroundStyle(Color(red: 0.91, green: 0.83, blue: 0.66))  // ds-allow: arte gamificada (mundo da trilha)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    MaletaMedicaIcone()
                        .frame(width: 34, height: 34)  // maleta grande, sem rótulo (Rafael)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("trail_filtro")
        .accessibilityLabel("Filtrar: \(filtroNome)")
        .devTag("Maleta (abre a gaveta de áreas)")
    }

    /// Chip da seção atual (ex.: "Seção 1 · Calouro"), ao lado da maleta. É o novo
    /// lar do tier: saiu da muralha porque o vidro glass da barra borrava o texto
    /// do mapa que passava atrás. O ponto colorido carrega a cor da fase.
    private var tierChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tierCor)
                .frame(width: 7, height: 7)
                .shadow(color: tierCor.opacity(0.7), radius: 3)  // brasa da fase
            Text("Seção \(tierNumero) · \(tierNome)")
                .font(.system(size: 11.5, weight: .semibold))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(Color(red: 0.91, green: 0.83, blue: 0.66))  // ds-allow: arte gamificada (mundo da trilha)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Seção \(tierNumero), \(tierNome)")
        .devTag("Chip da seção atual (topnav)")
    }

    /// Fogo com miolo quente — o flame.fill chapado some contra a madeira.
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

    /// Menu = três tábuas com prego nas pontas (opção B do protótipo).
    private var botaoMenu: some View {
        Button(action: aoTocarMenu) {
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
                        .overlay {
                            HStack {
                                prego; Spacer(); prego
                            }
                            .padding(.horizontal, 3)
                        }
                }
            }
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("trail_menu")
        .accessibilityLabel("Menu")
    }

    private var prego: some View {
        Circle()
            .fill(Color(red: 0.48, green: 0.33, blue: 0.15).opacity(0.7))  // ds-allow: arte gamificada (mundo da trilha)
            .frame(width: 1.7, height: 1.7)
    }

    /// Numeral ARREDONDADA e sem separador de milhar.
    /// `verbatim` é obrigatório: a interpolação normal do Text passa pelo
    /// formatador de local e devolve "3.049", que nesse corpo lê como decimal.
    private func numero(_ texto: String, cor: Color, sombra: Color) -> some View {
        Text(verbatim: texto)
            .font(.system(size: 17, weight: .heavy, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
            .monospacedDigit()
            .foregroundStyle(cor)
            .shadow(color: sombra, radius: 0, y: 1)
    }

    // O número herda a cor do ícone ao lado — é o que faz os dois virarem uma
    // peça só em vez de HUD com texto por cima.
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

// MARK: - Maleta médica (ícone do chip "Tudo")
//
// Maleta vermelha com cruz branca — colorida e tátil, no espírito do foguinho
// ao lado (gradiente + brilho no topo dão o material). É o símbolo escolhido
// pelo Rafael pra representar "medicina inteira". Coords lógicas 24×24.
struct MaletaMedicaIcone: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 24
            ctx.scaleBy(x: s, y: s)
            desenhar(&ctx)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var vermelho: Gradient {
        Gradient(stops: [
            .init(color: Color(red: 1.0, green: 0.42, blue: 0.37), location: 0),   // ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.90, green: 0.20, blue: 0.16), location: 0.55),// ds-allow: arte gamificada (mundo da trilha)
            .init(color: Color(red: 0.66, green: 0.09, blue: 0.09), location: 1)])  // ds-allow: arte gamificada (mundo da trilha)
    }

    private func desenhar(_ ctx: inout GraphicsContext) {
        // alça
        let alca = Path(roundedRect: CGRect(x: 8, y: 4.2, width: 8, height: 3.4), cornerRadius: 1.2)
        ctx.stroke(alca, with: .color(Color(red: 0.79, green: 0.80, blue: 0.82)),  // ds-allow: arte gamificada (mundo da trilha)
                   lineWidth: 1.6)

        // corpo da maleta
        let corpo = Path(roundedRect: CGRect(x: 3.4, y: 7, width: 17.2, height: 13), cornerRadius: 2.6)
        ctx.fill(corpo, with: .linearGradient(vermelho,
                                              startPoint: CGPoint(x: 12, y: 7),
                                              endPoint: CGPoint(x: 12, y: 20)))
        // brilho no topo (o "material" do foguinho)
        let brilho = Path(roundedRect: CGRect(x: 3.4, y: 7, width: 17.2, height: 4), cornerRadius: 2.6)
        ctx.fill(brilho, with: .color(.white.opacity(0.18)))

        // disco branco
        ctx.fill(Path(ellipseIn: CGRect(x: 7.6, y: 9.1, width: 8.8, height: 8.8)),
                 with: .linearGradient(
                    Gradient(colors: [.white, Color(red: 0.89, green: 0.90, blue: 0.92)]),  // ds-allow: arte gamificada (mundo da trilha)
                    startPoint: CGPoint(x: 12, y: 9), endPoint: CGPoint(x: 12, y: 18)))

        // cruz vermelha
        var cruz = Path()
        cruz.addRoundedRect(in: CGRect(x: 11, y: 10.6, width: 2, height: 6), cornerSize: CGSize(width: 0.5, height: 0.5))
        cruz.addRoundedRect(in: CGRect(x: 9, y: 12.6, width: 6, height: 2), cornerSize: CGSize(width: 0.5, height: 0.5))
        ctx.fill(cruz, with: .color(Color(red: 0.88, green: 0.18, blue: 0.16)))  // ds-allow: arte gamificada (mundo da trilha)
    }
}

// MARK: - Ícone colorido canônico por grande área
//
// UM ícone + UMA cor por área, iguais em toda tela (a fonte é o enum
// GrandeArea). Estilo da referência do Rafael: pastilha colorida arredondada +
// glifo branco. Trocar aqui muda em qualquer lugar que use AreaCardVita.
extension GrandeArea {
    /// Cor-assinatura da área (pastilha de fundo).
    var corAssinatura: Color {
        switch self {
        case .cicloBasico:            return Color(red: 0.56, green: 0.44, blue: 0.95)  // roxo — ds-allow: arte gamificada
        case .clinicaMedica:          return Color(red: 0.22, green: 0.60, blue: 0.98)  // azul — ds-allow: arte gamificada
        case .cirurgiaGeral:          return Color(red: 0.89, green: 0.24, blue: 0.34)  // carmim (issue #95) — ds-allow: arte gamificada
        case .ginecologiaObstetricia: return Color(red: 0.97, green: 0.42, blue: 0.70)  // rosa — ds-allow: arte gamificada
        case .pediatria:              return Color(red: 0.99, green: 0.68, blue: 0.22)  // âmbar — ds-allow: arte gamificada
        case .preventivaSocial:       return Color(red: 0.13, green: 0.73, blue: 0.62)  // teal — ds-allow: arte gamificada
        }
    }

    /// Glifo (SF Symbol) que casa com a referência — todos conferidos existentes.
    var glifoCanonico: String {
        switch self {
        case .cicloBasico:            return "book.fill"
        case .clinicaMedica:          return "stethoscope"
        case .cirurgiaGeral:          return "scissors"
        case .ginecologiaObstetricia: return "person.fill"   // placeholder do ♀; refino no hot reload
        case .pediatria:              return "teddybear.fill"
        case .preventivaSocial:       return "cross.case.fill"
        }
    }
}

/// Pastilha de VIDRO glossy 3D — o componente CANÔNICO da matéria colorida:
/// squircle · gradiente rico · faixa especular na metade de cima · rim light ·
/// halo da cor + relevo saltado. UM lugar só: muda aqui e muda nos 6 cards de
/// área E nos 93 chips de disciplina (é o "mesmo estilo" que o Rafael pediu —
/// os 6 de cima viram as 93 de baixo). O glifo branco entra por `conteudo`.
struct GlossyPastilha<Conteudo: View>: View {
    let cor: Color
    var lado: CGFloat = 52
    var raio: CGFloat = 17
    var selecionada: Bool = false
    @ViewBuilder var conteudo: () -> Conteudo

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: raio, style: .continuous)
        return forma
            // translucidez leve (issue #95 item 3): o painel de vidro fosco
            // aparece um tico por trás — botão vira "vidro colorido", não fill chapado.
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: cor.mais(0.22).opacity(0.90), location: 0),
                        .init(color: cor.opacity(0.90), location: 0.5),
                        .init(color: cor.menos(0.20).opacity(0.90), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
            )
            .background(.ultraThinMaterial, in: forma)   // frost por trás = glass de verdade
            // faixa especular: brilho de vidro cobrindo a metade de cima
            .overlay(alignment: .top) {
                forma
                    .fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.0)],
                                         startPoint: .top, endPoint: .bottom))
                    .padding(3)
                    .frame(height: lado * 0.577)   // metade de cima (52→30, escala junto)
                    .blendMode(.softLight)
            }
            // rim light: borda clara em cima (relevo saltado)
            .overlay {
                forma.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.08)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.2)
            }
            .overlay { conteudo() }
            // marca de seleção: anel claro + glow reforçado
            .overlay {
                if selecionada {
                    forma.strokeBorder(.white.opacity(0.95), lineWidth: 2.5)
                        .shadow(color: cor, radius: 6)
                }
            }
            .frame(width: lado, height: lado)
            .scaleEffect(selecionada ? 1.06 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selecionada)
            // halo da cor vazando em volta + sombra que ancora o botão
            .shadow(color: cor.opacity(0.65), radius: 8, y: 0)
            .shadow(color: .black.opacity(0.35), radius: 3, y: 3)
    }
}

/// Card de uma grande área na gaveta: pastilha glossy (glifo branco) + nome.
struct AreaCardVita: View {
    let area: GrandeArea
    var selecionada: Bool = false

    /// Glifo branco: Gineco usa o ♀ desenhado (SF não tem); resto usa SF.
    @ViewBuilder private var glifo: some View {
        if area == .ginecologiaObstetricia {
            GestanteIcone().frame(width: 27, height: 27)
        } else {
            Image(systemName: area.glifoCanonico)
                .font(.system(size: 21, weight: .semibold))  // ds-allow: arte gamificada
                .foregroundStyle(.white)
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            GlossyPastilha(cor: area.corAssinatura, lado: 52, raio: 17, selecionada: selecionada) {
                glifo
                    // sombra marcada = o glifo afunda no vidro (como na ref)
                    .shadow(color: area.corAssinatura.opacity(0.55), radius: 0.5, y: 1.5)
                    .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
            }

            Text(area.nomeCurto)
                .font(.system(size: 9, weight: selecionada ? .bold : .semibold))  // ds-allow: arte gamificada
                .foregroundStyle(selecionada
                                 ? .white
                                 : Color(red: 0.91, green: 0.83, blue: 0.66))  // ds-allow: arte gamificada
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 58, height: 22, alignment: .top)
                .minimumScaleFactor(0.75)
        }
        .contentShape(Rectangle())
    }
}

/// Triângulo apontando pra baixo — a "aba" do card selecionado (estilo Duolingo).
struct Triangulo: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Chip de disciplina na seção: anel de progresso (com o glifo/nome da área ao
/// centro) + nome. Sem % inventada — o anel usa o acerto REAL (nil = neutro).
struct DisciplinaChip: View {
    let disc: DisciplinaDaArea
    /// Cor HERDADA da área (issue #95 item 6): a pastilha segue a cor do pai, só
    /// o ícone muda. Override por disciplina (item 7, backend por slug) entra
    /// aqui no futuro — por ora o default é sempre a cor da área.
    let cor: Color

    // Símbolo próprio por disciplina (ZERO repetição na área) — do mapa canônico
    // por SLUG. A COR não vem mais daqui; vem da área. Rótulo limpo embaixo (1
    // linha quando cabe; 2 linhas com quebra só em fronteira de palavra/morfema).
    private var spec: (symbol: String, color: Color) {
        DisciplineImages.iconSpec(slug: disc.slug, name: disc.nome)
    }
    private var rotulo: String {
        DisciplineImages.shortLabel(slug: disc.slug, name: disc.nome)
    }

    var body: some View {
        VStack(spacing: 6) {
            GlossyPastilha(cor: cor, lado: 46, raio: 15) {
                glifo
                    .shadow(color: cor.opacity(0.55), radius: 0.5, y: 1.5)
                    .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
            }
            Text(rotulo)
                .font(.system(size: 11, weight: .semibold))  // ds-allow: arte gamificada
                .foregroundStyle(Color(red: 0.95, green: 0.90, blue: 0.80))  // ds-allow: arte gamificada
                .lineLimit(rotulo.contains("\n") ? 2 : 1)
                .multilineTextAlignment(.center)
                .frame(width: 60, height: 30, alignment: .top)
                .minimumScaleFactor(0.6)   // encolhe pra caber — NUNCA trunca com "…"
        }
    }

    /// Glifo branco: SF Symbol, ou glifo Canvas desenhado quando o símbolo vem
    /// com prefixo "custom:" (órgão que o SF não tem — estômago, rim, tireoide).
    @ViewBuilder private var glifo: some View {
        switch spec.symbol {
        case "custom:estomago": EstomagoIcone().frame(width: 27, height: 27)
        case "custom:rim":      RimIcone().frame(width: 26, height: 26)
        case "custom:tireoide": TireoideIcone().frame(width: 28, height: 28)
        case "custom:osso":     OssoIcone().frame(width: 27, height: 27)
        case "custom:bexiga":   BexigaIcone().frame(width: 25, height: 25)
        default:
            Image(systemName: spec.symbol)
                .font(.system(size: 21, weight: .semibold))  // ds-allow: arte gamificada
                .foregroundStyle(.white)
        }
    }
}

private extension Color {
    /// Clareia a cor (mistura com branco) — para o topo do gradiente/vidro.
    func mais(_ q: Double) -> Color {
        let u = UIColor(self); var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        u.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: min(1, r + q), green: min(1, g + q), blue: min(1, b + q))  // ds-allow: cor derivada de matiz (helper), nao literal
    }
    /// Escurece a cor — para a base do gradiente.
    func menos(_ q: Double) -> Color {
        let u = UIColor(self); var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        u.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: max(0, r - q), green: max(0, g - q), blue: max(0, b - q))  // ds-allow: cor derivada de matiz (helper), nao literal
    }
}

// MARK: - Ícone da gestante (Gineco e Obstetrícia)
//
// Silhueta branca de gestante de perfil com coração na barriga — como a
// referência do Rafael. SF Symbols não tem, então desenho no Canvas. Coords
// lógicas 24×24, glifo branco pra assentar sobre a pastilha rosa.
struct GestanteIcone: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 24
            ctx.scaleBy(x: s, y: s)
            let branco = GraphicsContext.Shading.color(.white)
            let l: CGFloat = 2.6  // espessura do traço

            // Símbolo ♀ (Vênus/feminino) — o canônico de ginecologia. Anel em
            // cima + haste + travessão embaixo. Legível em qualquer tamanho.
            let anel = Path(ellipseIn: CGRect(x: 7.2, y: 2.0, width: 9.6, height: 9.6))
            ctx.stroke(anel, with: branco, lineWidth: l)

            var haste = Path()
            haste.move(to: CGPoint(x: 12, y: 11.6))
            haste.addLine(to: CGPoint(x: 12, y: 21.4))
            ctx.stroke(haste, with: branco, style: StrokeStyle(lineWidth: l, lineCap: .round))

            var trav = Path()
            trav.move(to: CGPoint(x: 8.6, y: 17.4))
            trav.addLine(to: CGPoint(x: 15.4, y: 17.4))
            ctx.stroke(trav, with: branco, style: StrokeStyle(lineWidth: l, lineCap: .round))

            // coraçãozinho rosa dentro do anel — toque de "obstetrícia/vida"
            let rosa = GraphicsContext.Shading.color(Color(red: 0.95, green: 0.35, blue: 0.62))  // ds-allow: arte gamificada
            let cx = 12.0, cy = 6.6, r = 1.15
            var cor = Path()
            cor.move(to: CGPoint(x: cx, y: cy + 1.9))
            cor.addArc(center: CGPoint(x: cx - r, y: cy - 0.1), radius: r,
                       startAngle: .degrees(150), endAngle: .degrees(-30), clockwise: false)
            cor.addArc(center: CGPoint(x: cx + r, y: cy - 0.1), radius: r,
                       startAngle: .degrees(210), endAngle: .degrees(30), clockwise: false)
            cor.closeSubpath()
            ctx.fill(cor, with: rosa)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Ícone do estômago (Gastroenterologia)
//
// SF Symbols não tem estômago/intestino — e garfo+faca lia como "comer".
// Desenho a bolsa gástrica em J: fundo (domo) em cima-esquerda, corpo curvando
// pra direita até o piloro, esôfago entrando no topo e duodeno saindo embaixo.
// Coords lógicas 24×24, glifo branco pra assentar na pastilha colorida.
struct EstomagoIcone: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 24
            ctx.scaleBy(x: s, y: s)
            let branco = GraphicsContext.Shading.color(.white)

            // esôfago: tubo curto entrando no topo (cárdia)
            let esofago = Path(roundedRect: CGRect(x: 7.2, y: 1.6, width: 3.0, height: 5.2),
                               cornerRadius: 1.4)
            ctx.fill(esofago, with: branco)

            // corpo da bolsa gástrica (fundo em cima, piloro embaixo-direita)
            var corpo = Path()
            corpo.move(to: CGPoint(x: 8.7, y: 4.6))
            corpo.addCurve(to: CGPoint(x: 18.4, y: 10.2),          // domo + curvatura maior (direita)
                           control1: CGPoint(x: 15.2, y: 3.0), control2: CGPoint(x: 19.2, y: 5.6))
            corpo.addCurve(to: CGPoint(x: 13.6, y: 19.2),          // desce até o piloro
                           control1: CGPoint(x: 17.9, y: 14.6), control2: CGPoint(x: 17.6, y: 19.2))
            corpo.addCurve(to: CGPoint(x: 9.4, y: 14.2),           // incisura angular (curvatura menor)
                           control1: CGPoint(x: 10.8, y: 19.2), control2: CGPoint(x: 10.0, y: 16.8))
            corpo.addCurve(to: CGPoint(x: 10.6, y: 7.0),           // sobe pela curvatura menor
                           control1: CGPoint(x: 8.9, y: 11.4), control2: CGPoint(x: 9.3, y: 8.9))
            corpo.addCurve(to: CGPoint(x: 8.7, y: 4.6),            // fecha na cárdia
                           control1: CGPoint(x: 11.3, y: 5.6), control2: CGPoint(x: 9.9, y: 4.7))
            corpo.closeSubpath()
            ctx.fill(corpo, with: branco)

            // duodeno: tubo curvo saindo do piloro (embaixo-direita)
            var duodeno = Path()
            duodeno.move(to: CGPoint(x: 14.2, y: 18.4))
            duodeno.addQuadCurve(to: CGPoint(x: 17.8, y: 20.0),
                                 control: CGPoint(x: 15.4, y: 21.2))
            ctx.stroke(duodeno, with: branco,
                       style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Ícone do rim (Nefrologia)
//
// Feijão com o entalhe do hilo na borda interna (esquerda) — a marca que faz
// ler "rim" e não uma gota. Branco, coords 24×24.
struct RimIcone: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 24
            ctx.scaleBy(x: s, y: s)
            let branco = GraphicsContext.Shading.color(.white)

            var p = Path()
            p.move(to: CGPoint(x: 13, y: 3))
            p.addCurve(to: CGPoint(x: 19, y: 12),                 // curvatura externa (direita), convexa
                       control1: CGPoint(x: 17, y: 3.3), control2: CGPoint(x: 19, y: 7))
            p.addCurve(to: CGPoint(x: 13, y: 21),
                       control1: CGPoint(x: 19, y: 17), control2: CGPoint(x: 17, y: 21))
            p.addCurve(to: CGPoint(x: 9, y: 15.5),                // base
                       control1: CGPoint(x: 10.6, y: 21), control2: CGPoint(x: 9, y: 18.6))
            p.addQuadCurve(to: CGPoint(x: 9, y: 8.5),             // HILO: controle puxado p/ centro = entalhe côncavo
                           control: CGPoint(x: 12.7, y: 12))
            p.addCurve(to: CGPoint(x: 13, y: 3),
                       control1: CGPoint(x: 9, y: 5.4), control2: CGPoint(x: 10.6, y: 3.3))
            p.closeSubpath()
            ctx.fill(p, with: branco)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Ícone da tireoide (Endocrinologia)
//
// Glândula em borboleta: dois lobos (gota, polo superior apontando pro centro)
// unidos por um istmo central. É o símbolo do endócrino na referência do
// Rafael. Branco, coords 24×24.
struct TireoideIcone: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 24
            ctx.scaleBy(x: s, y: s)
            let branco = GraphicsContext.Shading.color(.white)

            // lobo esquerdo (gota: ponta em cima-centro, base redonda embaixo-fora)
            var esq = Path()
            esq.move(to: CGPoint(x: 11.4, y: 6.2))
            esq.addQuadCurve(to: CGPoint(x: 5.0, y: 12.0), control: CGPoint(x: 6.0, y: 6.4))
            esq.addQuadCurve(to: CGPoint(x: 8.2, y: 18.2), control: CGPoint(x: 4.6, y: 16.4))
            esq.addQuadCurve(to: CGPoint(x: 11.4, y: 13.4), control: CGPoint(x: 11.0, y: 16.6))
            esq.closeSubpath()
            ctx.fill(esq, with: branco)

            // lobo direito (espelho)
            var dir = Path()
            dir.move(to: CGPoint(x: 12.6, y: 6.2))
            dir.addQuadCurve(to: CGPoint(x: 19.0, y: 12.0), control: CGPoint(x: 18.0, y: 6.4))
            dir.addQuadCurve(to: CGPoint(x: 15.8, y: 18.2), control: CGPoint(x: 19.4, y: 16.4))
            dir.addQuadCurve(to: CGPoint(x: 12.6, y: 13.4), control: CGPoint(x: 13.0, y: 16.6))
            dir.closeSubpath()
            ctx.fill(dir, with: branco)

            // istmo: ponte central unindo os lobos
            let istmo = Path(roundedRect: CGRect(x: 10.0, y: 10.8, width: 4.0, height: 4.0),
                             cornerRadius: 1.3)
            ctx.fill(istmo, with: branco)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Ícone do osso (Ortopedia) — issue #95
// Osso diagonal clássico: haste + duas cabeças (2 nós) em cada ponta. Branco.
struct OssoIcone: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 24
            ctx.scaleBy(x: s, y: s)
            let branco = GraphicsContext.Shading.color(.white)
            var haste = Path()
            haste.move(to: CGPoint(x: 8, y: 8))
            haste.addLine(to: CGPoint(x: 16, y: 16))
            ctx.stroke(haste, with: branco, style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
            let r: CGFloat = 2.5
            for c in [CGPoint(x: 5.6, y: 7.4), CGPoint(x: 7.4, y: 5.6),
                      CGPoint(x: 18.4, y: 16.6), CGPoint(x: 16.6, y: 18.4)] {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: branco)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Ícone da bexiga (Urologia) — issue #95
// Bolsa arredondada com 2 ureteres entrando no topo e a uretra saindo embaixo —
// o que faz ler "urinário", não uma gota qualquer. Branco, 24×24.
struct BexigaIcone: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 24
            ctx.scaleBy(x: s, y: s)
            let branco = GraphicsContext.Shading.color(.white)

            var corpo = Path()
            corpo.move(to: CGPoint(x: 12, y: 6.5))
            corpo.addCurve(to: CGPoint(x: 18.6, y: 14),
                           control1: CGPoint(x: 16, y: 7), control2: CGPoint(x: 18.6, y: 10))
            corpo.addCurve(to: CGPoint(x: 12, y: 20.5),
                           control1: CGPoint(x: 18.6, y: 17.8), control2: CGPoint(x: 15.6, y: 20.5))
            corpo.addCurve(to: CGPoint(x: 5.4, y: 14),
                           control1: CGPoint(x: 8.4, y: 20.5), control2: CGPoint(x: 5.4, y: 17.8))
            corpo.addCurve(to: CGPoint(x: 12, y: 6.5),
                           control1: CGPoint(x: 5.4, y: 10), control2: CGPoint(x: 8, y: 7))
            corpo.closeSubpath()
            ctx.fill(corpo, with: branco)

            // ureteres (2 tubinhos no topo)
            for dx in [-3.2, 3.2] as [CGFloat] {
                var t = Path()
                t.move(to: CGPoint(x: 12 + dx * 0.55, y: 7.0))
                t.addLine(to: CGPoint(x: 12 + dx, y: 3.0))
                ctx.stroke(t, with: branco, style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
            }
            // uretra (stub embaixo)
            var u = Path()
            u.move(to: CGPoint(x: 12, y: 20.2))
            u.addLine(to: CGPoint(x: 12, y: 22.6))
            ctx.stroke(u, with: branco, style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Vidro do iOS 26 (Liquid Glass REAL)
//
// Troca o `.ultraThinMaterial` fosco (blur chapado, "tosco") pelo Liquid Glass
// de verdade do iOS 26 — que REFRATA e reflete o fundo via `.glassEffect`.
// `.clear` = variante mais transparente/refrativa (o "forte" que o Rafael pediu).
// Fallback pro material fosco em iOS < 26. Ref: developer.apple.com Liquid Glass.
extension View {
    @ViewBuilder
    func vidroLiquido(cornerRadius: CGFloat = 22) -> some View {
        let forma = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                // .regular = variante ADAPTATIVA (escurece/borra o fundo → texto
                // de cima legível). `.clear` fica transparente demais sobre o mapa
                // com texto (Rafael 2026-07-24). Ainda é Liquid Glass real.
                .glassEffect(.regular, in: forma)
                .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
        } else {
            self
                .background(forma.fill(.ultraThinMaterial))
                .overlay(
                    forma.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.40), .white.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 14, y: 7)
        }
    }
}
