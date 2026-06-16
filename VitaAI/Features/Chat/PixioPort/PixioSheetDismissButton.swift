import SwiftUI

// MARK: - PixioSheetDismissButton — canon ÚNICO de dismiss em sheets verticais
//
// Decisão Rafael 2026-05-06: TODO sheet que sobe de baixo pra cima usa este
// botão pra dismiss. Canon Apple HIG iOS 26 — sheet vertical sai com
// chevron.down (vertical), sheet horizontal sai com chevron.left.
//
// Pattern visual:
//   • SF Symbol `chevron.down` 14pt semibold
//   • foreground textLight @ muted opacity (sutil, não compete com title)
//   • SEM background circle (chrome flat — Apple HIG iOS 26)
//   • frame 36×36 pra hit area acessibilidade
//   • haptic .tap on press
//
// Animação dismiss (canon Rafael 2026-05-06):
//   • Sheet padrão SwiftUI já usa spring iOS — mas dismiss programático
//     via .dismiss() não respeita transition custom. Pra suavizar:
//     usamos .interactiveDismissDisabled(false) + presentationDragIndicator
//     pra deixar usuário arrastar com física natural.
//
// Uso em qualquer sheet (placement SEMPRE via .pixioDismiss — ver extension abaixo):
//   .toolbar {
//     ToolbarItem(placement: .pixioDismiss) {
//       PixioSheetDismissButton()
//     }
//   }

struct PixioSheetDismissButton: View {
    @Environment(\.dismiss) private var dismiss

    /// Override opcional do action (default = dismiss). Útil pra sheets
    /// com confirm dialog antes de fechar.
    var action: (() -> Void)? = nil
    /// Ícone do dismiss. Default `chevron.down` (sheet bottom-up); telas que
    /// entram/saem pela direita (overlay slide-da-direita) usam `chevron.right`.
    var icon: String = "chevron.down"

    var body: some View {
        Button {
            PixioHaptics.tap()
            if let action {
                action()
            } else {
                dismiss()
            }
        } label: {
            // Rafael 2026-06-12: dismiss agora é TILE PREMIUM (menor + alto nível,
            // consistente com o dialeto). Supera o "só a seta flat" anterior.
            PixioPremiumTile(size: 30, corner: 9) {
                Image(systemName: icon)
                    // pixio-design-gate-ignore: 12pt semibold canon dismiss
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PixioColor.textLight)
            }
        }
        // .plain força o nosso tile premium (sem o vidro/círculo automático do
        // toolbar iOS 26 Liquid Glass em volta de botão de toolbar).
        .buttonStyle(.plain)
        .accessibilityLabel("Fechar")
    }
}

// MARK: - Placement canônico (single source of truth do LADO do dismiss)

extension ToolbarItemPlacement {
    /// Canon ÚNICO do lado do botão de fechar em sheets.
    /// Decisão Rafael 2026-06-11: TODA tela fecha no canto superior **DIREITO**.
    /// Todo sheet usa `.pixioDismissToolbar(action:)` (helper abaixo) — NUNCA
    /// `.toolbar { ToolbarItem(placement: .pixioDismiss) {...} }` cru (sem a guarda
    /// iOS 26 ele ganha o círculo de vidro duplo em volta — Rafael 2026-06-15).
    static var pixioDismiss: ToolbarItemPlacement { .topBarTrailing }
}

// MARK: - Toolbar canônico de dismiss (single source — COM guarda iOS 26)

extension View {
    /// Adiciona o botão de fechar canônico (chevron.down clean) ao toolbar, no
    /// canto superior direito, JÁ com a guarda iOS 26 que remove o círculo/cápsula
    /// de vidro automática que o toolbar desenha em volta do nosso tile premium.
    ///
    /// Rafael 2026-06-15: "todos têm que ter APENAS esse botão clean, igual o
    /// drawer de categoria / Transações / Família — não o círculo duplo em volta".
    /// Mexeu AQUI = mudou em TODAS as telas. Use isto em vez do `.toolbar { ... }` cru.
    /// (Mesmo mecanismo que o `PixioSettingsScaffold` já aplica internamente.)
    @ViewBuilder
    func pixioDismissToolbar(action: @escaping () -> Void) -> some View {
        self.toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .pixioDismiss) {
                    PixioSheetDismissButton(action: action)
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .pixioDismiss) {
                    PixioSheetDismissButton(action: action)
                }
            }
        }
    }
}
