import SwiftUI

// MARK: - PixioPremiumToggle — switch grafite DIMENSIONAL (PORT do Pixio, cor Vita)
//
// Fonte: pixio-ios `Pixio/DesignSystem/Components/PixioPremiumToggle.swift`.
// Substitui o Toggle nativo verde em TODO o app. Aplicado GLOBAL via
// `.toggleStyle(PixioPremiumToggleStyle())` (o PixioSettingsScaffold já aplica).
//   • Trilho = RECESSO (inner shadow) — slot claro (off) → dourado gradiente (on).
//   • Knob   = peça que PEGA LUZ (gradiente claro + highlight + sombra projetada).
// SOT: agent-brain/decisions/2026-06-16_vita-pixio-ui-port.md
//
// NOTE do port: PixioPremiumTile e PixioThemeSchemeBar NÃO entram aqui — o tile já
// existe no PixioCompat (stub do chat) e o seletor de tema vem na migração do
// AppearanceScreen.

// pixio-design-gate-ignore: toggle premium — preto/transparente crus pras micro-sombras de profundidade física (neutras a tema, não são cor de UI)
private func ink(_ o: Double) -> Color { .black.opacity(o) }
private let clearToken: Color = .clear

/// Visual do switch — desenha a partir de `isOn` (sem estado próprio).
struct PixioPremiumSwitch: View {
    var isOn: Bool

    var body: some View {
        let w: CGFloat = 40, h: CGFloat = 24, pad: CGFloat = 2.5
        let knob = h - pad * 2
        let trackOn = LinearGradient(colors: [PixioColor.premiumLight, PixioColor.premiumDark],
                                     startPoint: .top, endPoint: .bottom)
        ZStack(alignment: isOn ? .trailing : .leading) {
            // TRILHO — recesso (inner shadow): slot claro (off) → dourado (on)
            Capsule()
                .fill(
                    (isOn ? AnyShapeStyle(trackOn) : AnyShapeStyle(PixioColor.textLightMuted.opacity(0.18)))
                        .shadow(.inner(color: ink(isOn ? 0.55 : 0.14), radius: 2, x: 0, y: 1))
                )
                .overlay( // fio de luz no topo da cápsula (rim light)
                    Capsule().strokeBorder(
                        LinearGradient(colors: [PixioColor.premiumText.opacity(isOn ? 0.16 : 0.55), clearToken],
                                       startPoint: .top, endPoint: .center),
                        lineWidth: 0.75)
                )
            // KNOB — peça dimensional que pega luz
            Circle()
                .fill(PixioMaterial.raisedFill)
                .overlay( // highlight especular no topo do knob
                    Circle()
                        .fill(LinearGradient(colors: [PixioColor.premiumText.opacity(0.95), clearToken],
                                             startPoint: .top, endPoint: .center))
                        .padding(1.4)
                )
                .frame(width: knob, height: knob)
                .shadow(color: ink(0.40), radius: 2.5, x: 0, y: 1.5)
                .padding(pad)
        }
        .frame(width: w, height: h)
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isOn)
    }
}

/// ToggleStyle premium — aplicar na raiz pra todo `Toggle` nativo virar grafite.
struct PixioPremiumToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: PixioSpacing.sm) {
            configuration.label
            Spacer(minLength: 0)
            PixioPremiumSwitch(isOn: configuration.isOn)
                .contentShape(Capsule())
                .onTapGesture {
                    configuration.isOn.toggle()
                    PixioHaptics.tap()
                }
        }
    }
}

// MARK: - PixioPremiumPillButtonStyle — CTA dimensional (pílula que pega luz)
//
// Botão premium reutilizável (Sair, ações de rodapé): pílula com superfície clara
// (gradiente) + rim light + sombra de elevação + feedback de press (afunda).
struct PixioPremiumPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, PixioSpacing.md)
            .background(
                Capsule().fill(PixioMaterial.raisedFill)
            )
            .overlay(
                Capsule().strokeBorder(PixioMaterial.rimStroke, lineWidth: 0.75)
            )
            // pixio-design-gate-ignore: elevação do CTA premium (regra do switcher)
            .shadow(color: ink(configuration.isPressed ? 0.06 : 0.13),
                    radius: configuration.isPressed ? 1 : 2.5, x: 0, y: configuration.isPressed ? 0.5 : 1.5)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
