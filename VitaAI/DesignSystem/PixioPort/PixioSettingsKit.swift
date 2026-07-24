import SwiftUI

// MARK: - PixioSettingsKit — dialeto canon do ecossistema Ajustes (PORT do Pixio)
//
// Fonte: pixio-ios `Pixio/DesignSystem/Components/PixioSettingsKit.swift` (Rafael
// 2026-06-02). Estrutura/forma do Pixio; cor DOURADA via PixioCompat.
// SOT: agent-brain/decisions/2026-06-16_vita-pixio-ui-port.md
//
// Primitivos:
//   • PixioSettingsScaffold — NavigationStack + aurora + ScrollView + dismiss
//   • PixioSettingsSection   — header pequeno uppercase + rows (sem caixa)
//   • PixioSettingsRow       — chip/tile + título (+ valor/status/chevron)
//   • PixioSettingsIcon      — tile mono dimensional (rim light)
//   • PixioSettingsDivider   — hairline alinhada sob o texto
//
// Regra: tela de Ajustes NÃO usa card "boxed" pra navegação. Usa estes.

// MARK: - Scaffold

private struct PixioInSettingsStackKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var pixioInSettingsStack: Bool {
        get { self[PixioInSettingsStackKey.self] }
        set { self[PixioInSettingsStackKey.self] = newValue }
    }
}

struct PixioSettingsScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pixioInSettingsStack) private var inStack

    let title: String
    /// Chamado ao fechar (além do dismiss). Default no-op.
    var onClose: () -> Void = {}
    /// Esconde o botão de fechar (telas empurradas via navegação, não sheet).
    var showsDismiss: Bool = true
    /// Ícone do dismiss quando a tela é ROOT. `chevron.down` (sheet) ou
    /// `chevron.right` (overlay que sai pela direita). Sub-telas empurradas usam
    /// SEMPRE `chevron.left` (voltar), automático.
    var dismissIcon: String = "chevron.down"
    /// Override opcional. Por padrão (nil) DETECTA automaticamente via environment.
    var pushed: Bool? = nil
    /// Override de tema do aurora. nil = tema ativo.
    var auroraTheme: PixioThemeColor? = nil
    /// `true` (default): envolve content em ScrollView. `false`: content é
    /// self-scrollable (lista nativa) — aninhar ScrollView colapsaria a height.
    var scrollable: Bool = true
    @ViewBuilder var content: () -> Content

    /// É uma sub-tela empurrada? Override explícito OU herdou o stack do pai.
    private var isPushed: Bool { pushed ?? inStack }
    private var effectiveDismissIcon: String { isPushed ? "chevron.left" : dismissIcon }

    var body: some View {
        if isPushed {
            scaffoldContent.navigationBarBackButtonHidden(true)
                .toggleStyle(PixioPremiumToggleStyle())
        } else {
            NavigationStack { scaffoldContent }
                .environment(\.pixioInSettingsStack, true)
                .toggleStyle(PixioPremiumToggleStyle())
        }
    }

    private var scaffoldContent: some View {
        ZStack {
            PixioAuroraBackground(themeOverride: auroraTheme).ignoresSafeArea()
            if scrollable {
                ScrollView {
                    VStack(alignment: .leading, spacing: PixioSpacing.md) {
                        content()
                    }
                    .padding(.horizontal, PixioSpacing.screenH)
                    .padding(.top, PixioSpacing.sm)
                    // pixio-design-gate-ignore: clearance do scaffold (safe area + tab bar)
                    .padding(.bottom, 80)
                }
            } else {
                content()
                    .padding(.horizontal, PixioSpacing.screenH)
                    .padding(.top, PixioSpacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDismiss {
                if #available(iOS 26.0, *) {
                    pixioDismissItem.sharedBackgroundVisibility(.hidden)
                } else {
                    pixioDismissItem
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var pixioDismissItem: some ToolbarContent {
        ToolbarItem(placement: .pixioDismiss) {
            PixioSheetDismissButton(action: {
                if isPushed {
                    dismiss()
                } else {
                    onClose()
                    dismiss()
                }
            }, icon: effectiveDismissIcon)
        }
    }
}

// MARK: - Section

/// Header pequeno uppercase + rows limpas (sem card box). Espelha o Ajustes.
struct PixioSettingsSection<Content: View>: View {
    let title: String?
    var onAdd: (() -> Void)? = nil
    var addLabel: String? = nil
    /// Chevron antes do título recolhe/expande a seção (default ABERTO).
    var collapsible: Bool = false
    @ViewBuilder var content: () -> Content

    @State private var expanded = true

    init(_ title: String? = nil, addLabel: String? = nil, collapsible: Bool = false, onAdd: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.addLabel = addLabel
        self.collapsible = collapsible
        self.onAdd = onAdd
        self.content = content
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(PixioTypo.geist(size: 11, weight: .semibold))
            .tracking(1.0)
            .foregroundStyle(PixioColor.textLightFaint)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PixioSpacing.xxs) {
            if title != nil || onAdd != nil {
                HStack(spacing: 0) {
                    if collapsible {
                        Button {
                            PixioHaptics.tap()
                            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                        } label: {
                            HStack(spacing: PixioSpacing.xs) {
                                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                    .font(PixioTypo.micro)
                                    .foregroundStyle(PixioColor.textLightFaint)
                                if let title { sectionTitle(title) }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else if let title {
                        sectionTitle(title)
                    }

                    if onAdd != nil { Spacer() }
                    if let onAdd {
                        Button {
                            PixioHaptics.tap()
                            onAdd()
                        } label: {
                            if let addLabel {
                                Text(addLabel)
                                    .font(PixioTypo.caption)
                                    .foregroundStyle(PixioColor.textLightMuted)
                            } else {
                                Image(systemName: "plus")
                                    .font(PixioTypo.cardTitle)
                                    .foregroundStyle(PixioColor.premium)
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(addLabel ?? "Adicionar")
                    }
                }
                .padding(.leading, PixioSpacing.xs)
                .padding(.bottom, PixioSpacing.xs)
            }
            if !collapsible || expanded {
                VStack(spacing: 0) { content() }
            }
        }
    }
}

// MARK: - Search field

/// Campo de busca canônico — lupa + TextField + clear, sobre `.pixioFieldSurface`.
struct PixioSearchField: View {
    @Binding var text: String
    var placeholder: String = "Buscar"

    var body: some View {
        HStack(spacing: PixioSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(PixioTypo.caption)
                .foregroundStyle(PixioColor.textLightMuted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(PixioTypo.body)
                .foregroundStyle(PixioColor.textLight)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    PixioHaptics.tap()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(PixioTypo.body)
                        .foregroundStyle(PixioColor.textLightFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PixioSpacing.md)
        .padding(.vertical, PixioSpacing.sm)
        .pixioFieldSurface()
    }
}

// MARK: - Icon chip

/// Chip circular tonal com o ícone na cor de destaque.

// pixio-design-gate-ignore: dialeto Ajustes — preto/transparente crus pras micro-sombras de profundidade física do tile (neutras a tema)
private func ink(_ o: Double) -> Color { .black.opacity(o) }
private let clearToken: Color = .clear

/// Ícone do dialeto Ajustes — MONO num TILE dimensional (luz + profundidade).
struct PixioSettingsIcon: View {
    let icon: String
    var destructive: Bool = false
    /// Asset de marca no lugar do SF Symbol, tingido por `assetTint`.
    var assetName: String? = nil
    var assetTint: Color? = nil

    var body: some View {
        glyph
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PixioMaterial.raisedFill)
            )
            .overlay( // rim light no topo (catch light)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [PixioColor.premiumText.opacity(0.55), clearToken],
                                                 startPoint: .top, endPoint: .center),
                                  lineWidth: 0.75)
            )
            // pixio-design-gate-ignore: elevação sutil do tile (regra do switcher)
            .shadow(color: ink(0.10), radius: 1.5, x: 0, y: 1)
    }

    @ViewBuilder
    private var glyph: some View {
        if let assetName {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundStyle(assetTint ?? PixioColor.textLight)
        } else {
            Image(systemName: icon)
                .font(PixioTypo.sans(size: 14, weight: .regular))
                .foregroundStyle(destructive ? PixioColor.negative : PixioColor.textLight)
        }
    }
}

// MARK: - Divider

/// Hairline alinhada sob o texto (tile 28 + spacing 14 = 42).
struct PixioSettingsDivider: View {
    var body: some View {
        Divider().padding(.leading, 42)
    }
}

// MARK: - Row

/// Row canon do settings: tile + título, com valor/status opcional à direita e
/// chevron. `action == nil` → row informativa (sem toque/chevron).
struct PixioSettingsRow: View {
    let icon: String
    let accent: Color
    let title: String
    /// Texto de valor/status à direita (ex.: "Grátis").
    var value: String? = nil
    /// Mostra um selo verde de verificado antes do valor.
    var verified: Bool = false
    var showChevron: Bool = true
    var destructive: Bool = false
    /// Override do ícone-líder (ex: ícone REAL de categoria). nil = padrão (tile mono).
    var leadingOverride: AnyView? = nil
    var action: (() -> Void)? = nil

    private var titleColor: Color { destructive ? PixioColor.negative : PixioColor.textLight }

    @ViewBuilder
    private var rowBody: some View {
        HStack(spacing: 14) {
            if let leadingOverride {
                leadingOverride
            } else {
                PixioSettingsIcon(icon: icon, destructive: destructive)
            }
            Text(title)
                .font(PixioTypo.geist(size: 15, weight: .regular))
                .foregroundStyle(titleColor)
            Spacer(minLength: 8)
            if verified {
                Image(systemName: "checkmark.seal.fill")
                    .font(PixioTypo.sans(size: 12, weight: .semibold))
                    .foregroundStyle(PixioColor.positive)
            }
            if let value {
                Text(value)
                    .font(PixioTypo.geist(size: 15, weight: .regular))
                    .foregroundStyle(PixioColor.textLightMuted)
                    .lineLimit(1)
            }
            if showChevron, action != nil {
                Image(systemName: "chevron.right")
                    .font(PixioTypo.sans(size: 13, weight: .semibold))
                    .foregroundStyle(PixioColor.textLightFaint)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    var body: some View {
        if let action {
            Button {
                PixioHaptics.tap()
                action()
            } label: { rowBody }
            .buttonStyle(.plain)
        } else {
            rowBody
        }
    }
}

// MARK: - Toggle Row

/// Row canon com Toggle nativo à direita — preferências on/off. Mesmo dialeto da
/// PixioSettingsRow (tile + título). O Toggle herda o PixioPremiumToggleStyle.
struct PixioSettingsToggleRow: View {
    let icon: String
    let accent: Color
    let title: String
    /// Status/valor opcional à direita do título (ex: "Ativa"/"Inativa").
    var value: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            PixioSettingsIcon(icon: icon)
            Text(title)
                .font(PixioTypo.geist(size: 15, weight: .regular))
                .foregroundStyle(PixioColor.textLight)
                .lineLimit(1)
            Spacer(minLength: PixioSpacing.sm)
            if let value {
                Text(value)
                    .font(PixioTypo.caption)
                    .foregroundStyle(PixioColor.textLightMuted)
            }
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 10)
    }
}
