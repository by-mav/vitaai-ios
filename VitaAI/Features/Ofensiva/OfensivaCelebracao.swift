import SwiftUI

// MARK: - Comemoração da ofensiva

/// Aparece UMA vez por dia, **depois do primeiro estudo do dia** — nunca ao
/// abrir o app. Na entrada a pessoa veio fazer algo e ainda não conquistou
/// nada: tela cheia ali é pedágio. Depois de estudar, a mesma tela é prêmio.
///
/// Some sozinha, e toque em qualquer lugar pula.
struct VitaOfensivaCelebracao: View {
    let dias: Int
    var aoFechar: () -> Void

    @State private var mostraChama = false
    @State private var mostraNumero = false
    @State private var mostraSelo = false
    @State private var diasNaTela = 0

    /// Tempo até sumir sozinha. Curto de propósito: é comemoração, não anúncio.
    private let tempoNaTela: Duration = .seconds(4)

    var body: some View {
        ZStack {
            // A tela de onde a pessoa veio continua ali atrás, quase apagada:
            // mostra o contexto sem competir.
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: VitaTokens.Spacing.xl) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [VitaColors.accent.opacity(0.34), .clear],
                                center: .center, startRadius: 4, endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .opacity(mostraChama ? 1 : 0)

                    ChamaOfensiva(ativa: mostraChama, tamanho: 96)
                        .foregroundStyle(VitaColors.accent)
                        .scaleEffect(mostraChama ? 1 : 0.3)
                        .opacity(mostraChama ? 1 : 0)
                }

                VStack(spacing: VitaTokens.Spacing.sm) {
                    Text("SUA OFENSIVA")
                        .font(VitaTypography.labelSmall)
                        .tracking(VitaTokens.Typography.letterSpacingWide * 3)
                        .foregroundStyle(VitaColors.textSecondary)
                        .opacity(mostraNumero ? 1 : 0)

                    HStack(alignment: .firstTextBaseline, spacing: VitaTokens.Spacing.md) {
                        Text("Dia")
                            .foregroundStyle(VitaColors.textPrimary)
                        Text("\(diasNaTela)")
                            .foregroundStyle(VitaColors.accent)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .font(PixioTypo.sans(size: 64, weight: .bold))
                    .opacity(mostraNumero ? 1 : 0)
                    .scaleEffect(mostraNumero ? 1 : 0.86)
                }

                Text("+1 OFENSIVA")
                    .font(VitaTypography.labelMedium)
                    .fontWeight(.semibold)
                    .tracking(VitaTokens.Typography.letterSpacingWide * 2)
                    .foregroundStyle(VitaColors.accent)
                    .padding(.horizontal, VitaTokens.Spacing.xl)
                    .padding(.vertical, VitaTokens.Spacing.sm)
                    .overlay(
                        Capsule().strokeBorder(VitaColors.accent.opacity(0.55), lineWidth: 1)
                    )
                    .opacity(mostraSelo ? 1 : 0)
                    .scaleEffect(mostraSelo ? 1 : 0.9)

                Spacer()

                VitaButton(text: "Continuar", action: fechar)
                    .padding(.horizontal, VitaTokens.Spacing._2xl)
                    .padding(.bottom, VitaTokens.Spacing._2xl)
                    .opacity(mostraSelo ? 1 : 0)
            }
        }
        // Toque em qualquer lugar pula: nunca prender a pessoa numa comemoração.
        .contentShape(Rectangle())
        .onTapGesture(perform: fechar)
        .task { await encenar() }
    }

    /// A chama nasce, o número vira, o selo entra. É a ordem que carrega a
    /// emoção — tudo aparecendo junto não comemora nada.
    private func encenar() async {
        diasNaTela = max(0, dias - 1)

        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { mostraChama = true }
        try? await Task.sleep(for: .milliseconds(340))

        withAnimation(.easeOut(duration: 0.28)) { mostraNumero = true }
        try? await Task.sleep(for: .milliseconds(220))

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { diasNaTela = dias }
        try? await Task.sleep(for: .milliseconds(260))

        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { mostraSelo = true }

        try? await Task.sleep(for: tempoNaTela)
        fechar()
    }

    private func fechar() {
        withAnimation(.easeOut(duration: 0.22)) { aoFechar() }
    }
}

// MARK: - Quando mostrar

/// Guarda de "uma vez por dia".
///
/// A chave é o DIA que veio do servidor, não o relógio do aparelho: quem viaja
/// ou mexe na hora não deve ver a comemoração de novo — nem deixar de ver.
@MainActor
final class ControleComemoracaoOfensiva: ObservableObject {
    @Published private(set) var diasParaComemorar: Int?

    private let chave = "ofensivaComemoradaEm"       // dia do SERVIDOR: 1x/dia real
    private let chaveLocal = "ofensivaFetchLocalEm"  // dia do APARELHO: trava de fetch

    /// True se ja avaliei hoje (data do aparelho). Evita buscar a ofensiva a
    /// cada flashcard: depois da 1a comemoracao do dia, para de buscar.
    var jaAvaliouHojeLocal: Bool {
        UserDefaults.standard.string(forKey: chaveLocal) == Self.diaLocalHoje()
    }

    private static func diaLocalHoje() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Chame depois de um estudo concluído. Só dispara se: a pessoa estudou
    /// hoje, tem sequência viva, e ainda não viu a comemoração deste dia.
    func avaliar(ofensiva: Ofensiva, diaDoServidor: String) {
        guard ofensiva.studiedToday, ofensiva.currentStreak > 0 else { return }
        guard !diaDoServidor.isEmpty else { return }
        guard UserDefaults.standard.string(forKey: chave) != diaDoServidor else { return }
        UserDefaults.standard.set(diaDoServidor, forKey: chave)
        UserDefaults.standard.set(Self.diaLocalHoje(), forKey: chaveLocal)
        diasParaComemorar = ofensiva.currentStreak
    }

    func fechar() { diasParaComemorar = nil }
}
