import SwiftUI

// MARK: - Baú do tesouro + moeda (Rafael 2026-07-14)
//
// A Caixa Misteriosa virou BAÚ: um baú do tesouro desenhado que ABRE (tampa
// levanta + explosão de luz da cor da raridade) e revela a skin sorteada, que
// sobe de dentro do baú. Arte gamificada — cores/fontes cruas são visual
// signature (ds-allow), fora dos tokens Vita.

// MARK: Moeda (ícone de verdade — dourada, com brilho e "V" de Vita)

struct CoinIcon: View {
    var size: CGFloat = 16
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.90, blue: 0.52),   // ds-allow: moeda (loja gamificada) — visual signature
                            Color(red: 0.86, green: 0.62, blue: 0.18),  // ds-allow: moeda (loja gamificada) — visual signature
                        ],
                        center: UnitPoint(x: 0.34, y: 0.30), startRadius: 0, endRadius: size
                    )
                )
            Circle()
                .stroke(Color(red: 0.60, green: 0.42, blue: 0.10), lineWidth: max(1, size * 0.06))  // ds-allow: moeda (loja gamificada) — visual signature
            Circle()
                .stroke(Color(red: 1.0, green: 0.94, blue: 0.66).opacity(0.55), lineWidth: max(0.8, size * 0.045))  // ds-allow: moeda (loja gamificada) — visual signature
                .padding(size * 0.20)
            Text("V")
                .font(.system(size: size * 0.52, weight: .black))  // ds-allow: moeda (loja gamificada) — visual signature
                .foregroundStyle(Color(red: 0.52, green: 0.36, blue: 0.06))  // ds-allow: moeda (loja gamificada) — visual signature
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 0.20, height: size * 0.20)
                .offset(x: -size * 0.20, y: -size * 0.22)
        }
        .frame(width: size, height: size)
    }
}

// MARK: Baú do tesouro (tampa abre com rotação 3D)

struct TreasureChestView: View {
    var open: Bool
    var accent: Color
    var width: CGFloat = 150

    private let wood = Color(red: 0.44, green: 0.27, blue: 0.14)       // ds-allow: baú (loja gamificada) — visual signature
    private let woodDark = Color(red: 0.26, green: 0.15, blue: 0.07)   // ds-allow: baú (loja gamificada) — visual signature
    private let goldA = Color(red: 1.0, green: 0.83, blue: 0.40)       // ds-allow: baú (loja gamificada) — visual signature
    private let goldB = Color(red: 0.76, green: 0.53, blue: 0.15)      // ds-allow: baú (loja gamificada) — visual signature

    private var lidH: CGFloat { width * 0.36 }
    private var bodyH: CGFloat { width * 0.50 }

    private var goldGrad: LinearGradient {
        LinearGradient(colors: [goldA, goldB], startPoint: .top, endPoint: .bottom)
    }
    private var woodGrad: LinearGradient {
        LinearGradient(colors: [wood, woodDark], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        ZStack {
            // Luz de dentro do baú quando abre.
            RadialGradient(colors: [accent.opacity(open ? 0.95 : 0), .clear],
                           center: .center, startRadius: 2, endRadius: width * 0.85)
                .frame(width: width * 1.7, height: width * 1.7)
                .offset(y: -lidH * 0.2)
                .allowsHitTesting(false)

            VStack(spacing: -3) {
                // Tampa: fechada encaixa no corpo; aberta LEVANTA e inclina pra trás,
                // revelando a boca do baú (abertura 2D confiável, não some).
                lid
                    .frame(width: width, height: lidH)
                    .rotationEffect(.degrees(open ? -14 : 0), anchor: .bottom)
                    .offset(y: open ? -lidH * 0.95 : 0)
                    .zIndex(1)
                chestBody
                    .frame(width: width, height: bodyH)
                    .overlay(alignment: .top) {
                        // Boca do baú: luz da raridade saindo de dentro quando abre.
                        if open {
                            RoundedRectangle(cornerRadius: 6)  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
                                .fill(LinearGradient(colors: [accent, accent.opacity(0)],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(height: bodyH * 0.5)
                                .blur(radius: 4)
                                .padding(.horizontal, width * 0.09)
                                .offset(y: -bodyH * 0.06)
                        }
                    }
            }
        }
        .frame(width: width * 1.15, height: (lidH + bodyH) * 1.35)
    }

    private var lid: some View {
        ZStack {
            UnevenRoundedRectangle(topLeadingRadius: lidH * 0.55, bottomLeadingRadius: 3,  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
                                   bottomTrailingRadius: 3, topTrailingRadius: lidH * 0.55)  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
                .fill(woodGrad)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: lidH * 0.55, bottomLeadingRadius: 3,  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
                                           bottomTrailingRadius: 3, topTrailingRadius: lidH * 0.55)  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
                        .stroke(goldB, lineWidth: 2)
                )
            bands
            // Trilho dourado no topo da tampa.
            VStack {
                RoundedRectangle(cornerRadius: 4).fill(goldGrad).frame(height: lidH * 0.16)  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
                Spacer()
            }
            .padding(.horizontal, 8).padding(.top, 4)
        }
    }

    private var chestBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(woodGrad)  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(goldB, lineWidth: 2))  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
            bands
            lock.offset(y: -bodyH * 0.28)
        }
    }

    private var bands: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(goldGrad).frame(width: width * 0.07)  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
            Spacer()
            RoundedRectangle(cornerRadius: 2).fill(goldGrad).frame(width: width * 0.08)  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
            Spacer()
            RoundedRectangle(cornerRadius: 2).fill(goldGrad).frame(width: width * 0.07)  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
        }
        .padding(.horizontal, width * 0.13)
    }

    private var lock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(goldGrad).frame(width: width * 0.17, height: width * 0.15)  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(goldB, lineWidth: 1))  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
            Circle().fill(woodDark).frame(width: width * 0.045, height: width * 0.045).offset(y: -width * 0.012)
            Rectangle().fill(woodDark).frame(width: width * 0.02, height: width * 0.045).offset(y: width * 0.015)
        }
    }
}

// MARK: Revelação

struct LootboxRevealView: View {
    let result: LootboxResult
    let onEquip: () -> Void
    let onClose: () -> Void

    @Environment(\.appData) private var appData
    @Environment(\.appContainer) private var container

    @State private var phase: Phase = .closed
    @State private var chestScale: CGFloat = 0.6
    @State private var chestOpen = false
    @State private var shake: CGFloat = 0
    @State private var orbScale: CGFloat = 0.3
    @State private var orbOpacity: CGFloat = 0
    @State private var orbRise: CGFloat = 0
    @State private var textOpacity: CGFloat = 0

    private enum Phase { case closed, revealed }

    private var rarityColor: Color {
        switch result.won.rarity {
        case "legendary": return Color(red: 1.0, green: 0.70, blue: 0.25)  // dourado lendário  // ds-allow: baú (loja gamificada) — visual signature
        case "epic": return Color(red: 0.78, green: 0.48, blue: 1.0)       // roxo épico        // ds-allow: baú (loja gamificada) — visual signature
        case "rare": return Color(red: 0.36, green: 0.72, blue: 1.0)       // azul raro         // ds-allow: baú (loja gamificada) — visual signature
        default:      return Color(red: 0.66, green: 0.70, blue: 0.78)     // prata comum       // ds-allow: baú (loja gamificada) — visual signature
        }
    }
    private var rarityLabel: String {
        switch result.won.rarity {
        case "legendary": return "LENDÁRIA"
        case "epic": return "ÉPICA"
        case "rare": return "RARA"
        default: return "COMUM"
        }
    }

    private var wonOrb: OrbMascot {
        OrbMascot(
            palette: .vita, size: 96,
            accessories: MascotAccessory(rawValue: result.won.id).map { [$0] } ?? [],
            animated: true,
            nameTag: VitaMascotEquipped.firstName(appData.profile?.displayName),
            photoURL: container.authManager.userImage.flatMap(URL.init(string:))
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()  // ds-allow: baú (loja gamificada) — visual signature
                .onTapGesture { if phase == .revealed { onClose() } }

            RadialGradient(colors: [rarityColor.opacity(0.28 * (chestOpen ? 1 : 0.4)), .clear],
                           center: .center, startRadius: 4, endRadius: 320)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 10) {
                Spacer()

                ZStack {
                    TreasureChestView(open: chestOpen, accent: rarityColor)
                        .scaleEffect(chestScale)
                        .offset(x: shake)

                    // Skin sobe de dentro do baú.
                    if phase == .revealed {
                        wonOrb
                            .frame(width: 96, height: 96)
                            .scaleEffect(orbScale)
                            .opacity(orbOpacity)
                            .offset(y: orbRise)
                            .shadow(color: rarityColor.opacity(0.6), radius: 22)
                    }
                }
                .frame(height: 210)

                VStack(spacing: 8) {
                    Text(rarityLabel)
                        .font(.system(size: 12, weight: .heavy)).tracking(3)  // ds-allow: baú (loja gamificada) — visual signature
                        .foregroundStyle(rarityColor)
                    Text(result.won.name)
                        .font(.system(size: 25, weight: .bold))  // ds-allow: baú (loja gamificada) — visual signature
                        .foregroundStyle(.white)
                    Text(result.duplicate == true ? "Item repetido · já estava no guarda-roupa" : "Você ganhou!")
                        .font(.system(size: 14))  // ds-allow: baú (loja gamificada) — visual signature
                        .foregroundStyle(.white.opacity(0.6))
                }
                .opacity(textOpacity)

                Spacer()
            }

            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button(action: onClose) {
                        Text("Continuar")
                            .font(.system(size: 15, weight: .semibold))  // ds-allow: baú (loja gamificada) — visual signature
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.10)))  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
                    }
                    Button(action: onEquip) {
                        Text("Equipar")
                            .font(.system(size: 15, weight: .bold))  // ds-allow: baú (loja gamificada) — visual signature
                            .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.14))  // ds-allow: baú (loja gamificada) — visual signature
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(rarityColor))  // ds-allow: bau (arte gamificada loja/trilha) - visual signature
                    }
                }
                .padding(.horizontal, 28).padding(.bottom, 44)
                .opacity(textOpacity)
            }
        }
        .onAppear { runReveal() }
    }

    private func runReveal() {
        // 1. Baú surge + treme (antecipação).
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { chestScale = 1.0 }
        withAnimation(.easeInOut(duration: 0.07).repeatCount(8, autoreverses: true).delay(0.4)) {
            shake = 6
        }
        // 2. Tampa abre.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { chestOpen = true }
        }
        // 3. Skin sobe de dentro + textos.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) {
            phase = .revealed
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                orbScale = 1.0
                orbOpacity = 1
                orbRise = -96
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.2)) { textOpacity = 1 }
        }
    }
}
