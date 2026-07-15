import SwiftUI

// MARK: - VitaScreenHeader — cabeçalho canônico de página empurrada
//
// Rafael 2026-07-15: as telas empurradas são full-bleed (a casca esconde a
// barra do sistema e o VitaTopBar global só aparece na Home). Sem um voltar
// próprio, o usuário fica preso. Este é o cabeçalho ÚNICO dessas páginas:
// botão voltar (chevron) + título grande e clean, com slot opcional de ação
// à direita. Uma casa só — todas as telas empurradas usam este componente,
// pra ninguém ficar preso e o título ter sempre a mesma tipografia.
//
// Uso:
//   VitaScreenHeader(title: "Disciplinas")                 // voltar padrão (router.goBack)
//   VitaScreenHeader(title: "X", onBack: { ... })          // voltar customizado
//   VitaScreenHeader(title: "X") { Button(...) { ... } }   // com ação à direita

struct VitaScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    @Environment(Router.self) private var router

    var body: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Button {
                PixioHaptics.tap()
                if let onBack { onBack() } else { router.goBack() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))  // ds-allow: back chevron (padrão do app)
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar")

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(VitaTypography.headlineMedium)  // 24pt semibold — título grande, clean
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, VitaTokens.Spacing.md)
        .padding(.top, VitaTokens.Spacing.sm)
        .padding(.bottom, 2)
    }
}

// Conveniência: sem ação à direita (o caso comum) — não precisa passar closure.
extension VitaScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, onBack: (() -> Void)? = nil) {
        self.init(title: title, subtitle: subtitle, onBack: onBack, trailing: { EmptyView() })
    }
}
