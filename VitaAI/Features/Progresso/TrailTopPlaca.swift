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

    var aoTocarFiltro: () -> Void
    var aoTocarOfensiva: () -> Void
    var aoTocarMoedas: () -> Void
    var aoTocarMenu: () -> Void

    private let altura: CGFloat = 48

    var body: some View {
        HStack(spacing: 11) {
            botaoFiltro
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
        .background(tabua)
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
        Button(action: aoTocarFiltro) {
            HStack(spacing: 6) {
                Image(systemName: filtroSimbolo ?? "staroflife.fill")
                    .font(.system(size: 17, weight: .semibold))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(TrailWorld.fireflyWarm)
                Text(filtroNome)
                    .font(.system(size: 12, weight: .bold))       // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(Color(red: 0.91, green: 0.83, blue: 0.66))  // ds-allow: arte gamificada (mundo da trilha)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("trail_filtro")
        .accessibilityLabel("Filtrar: \(filtroNome)")
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
