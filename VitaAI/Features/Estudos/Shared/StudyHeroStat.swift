import SwiftUI

/// Unified rich hero block shared across the StudySuite shells
/// (Questões / Flashcards / Simulados / Transcrição).
///
/// Liquid-glass premium silhouette: dark themed surface + radial glow + soft
/// decorative motif + eyebrow + large primary number + mini stats strip at
/// the bottom. Each tool injects its signature hue via `StudyShellTheme` so
/// the four pages feel connected to their dashboard entry point (brain
/// orange / heart purple / silhouette blue / microphone teal) while sharing
/// one layout, one set of paddings, one set of radii.
///
/// Rafael's ask (2026-04-18): "hero tem que ter bordas e efeitos de luz e
/// profundidade dentro, numero grande, liquid glass premium, cores do item
/// do dashboard correspondente". That is what this component renders.
struct StudyHeroStat: View {
    /// Big headline number (e.g. "174", "85%", "7.4"). Caller formats the unit.
    let primary: String
    /// Valor numerico por tras de `primary`. Quando presente, os digitos ROLAM
    /// (odometro) a cada mudanca em vez de trocar seco — o numero desce conforme
    /// o filtro aperta. Nil = texto estatico (heros que nao sao contagem).
    var primaryValue: Double? = nil
    /// Small caption under the headline ("cards pra revisar", "acertos", ...)
    let primaryCaption: String
    /// Mini stats shown in a strip along the bottom. 0-3 entries look clean.
    let stats: [Stat]
    /// Optional subtitle shown before the eyebrow label — rarely used.
    var subtitle: String? = nil
    /// Theme that drives hue, surface gradient, motif, eyebrow label.
    /// Defaults to Questões so existing callers don't break mid-refactor.
    var theme: StudyShellTheme = .questoes

    struct Stat: Identifiable {
        let id = UUID()
        let value: String
        let label: String
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.surfaceTop, theme.surfaceBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [theme.glow.opacity(0.13), theme.glow.opacity(0.0)],
                        center: .topTrailing,
                        startRadius: 6,
                        endRadius: 180
                    )
                )
                .blendMode(.screen)

            Image(systemName: theme.motifSymbol)
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(theme.primary.opacity(0.045))
                .rotationEffect(.degrees(-8))
                .offset(x: 18, y: -6)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .allowsHitTesting(false)

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    eyebrow

                    Text(primary)
                        .font(PixioTypo.sans(size: 34, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.primaryLight, theme.primary],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: theme.primary.opacity(0.16), radius: 8, y: 0)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        // Odometro: `numericText(value:)` sabe se o numero subiu ou
                        // desceu e rola o digito pro lado certo (desce quando o filtro
                        // aperta). `monospacedDigit` trava a largura pra coluna nao
                        // tremer enquanto rola.
                        .monospacedDigit()
                        .contentTransition(.numericText(value: primaryValue ?? 0))
                        .animation(.snappy(duration: 0.42), value: primaryValue)

                    Text(primaryCaption)
                        .font(PixioTypo.caption)
                        .foregroundStyle(Color.white.opacity(0.58))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !stats.isEmpty {
                    statsStrip
                        .frame(width: 116, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), .clear],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.10)
                    )
                )
                .frame(height: 8)
                .padding(.horizontal, 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.11),
                            theme.primary.opacity(0.08),
                            Color.white.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: theme.primary.opacity(0.10), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.24), radius: 10, x: 0, y: 4)
    }

    // MARK: - Eyebrow (dot + uppercased theme label + optional subtitle)

    private var eyebrow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(theme.primary)
                .frame(width: 5, height: 5)
                .shadow(color: theme.primary.opacity(0.45), radius: 3)
            Text(subtitle ?? theme.eyebrow)
                .font(PixioTypo.micro)
                .foregroundStyle(theme.primaryLight.opacity(0.76))
        }
    }

    // MARK: - Compact stats stack

    private var statsStrip: some View {
        VStack(alignment: .trailing, spacing: 7) {
            ForEach(stats) { stat in
                VStack(alignment: .trailing, spacing: 1) {
                    Text(stat.value)
                        .font(PixioTypo.sans(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(stat.label)
                        .font(PixioTypo.micro)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Editorial image hero

struct StudyImageHeroStat: View {
    let imageAsset: String
    let eyebrow: String
    let primary: String
    /// Valor numerico por tras de `primary` — ver `StudyHeroStat.primaryValue`.
    /// Presente = digitos rolam (odometro) conforme o filtro muda o pool.
    var primaryValue: Double? = nil
    let primaryCaption: String
    let stats: [StudyHeroStat.Stat]
    var theme: StudyShellTheme = .questoes
    /// Ação principal DENTRO do card (Rafael 2026-07-20, comparando com a
    /// referência). Ela fecha a frase que o hero começa: "118.751 questões
    /// disponíveis → Iniciar". Exilada numa barra no rodapé, ficava longe do
    /// número que justifica ela existir. Nil = hero sem ação (Jornada, etc).
    var action: Action? = nil

    struct Action {
        let title: String
        var isLoading: Bool = false
        var isEnabled: Bool = true
        let handler: () -> Void
    }

    /// Piso do card: abaixo disso a ilustração não tem espaço pra existir.
    /// É MÍNIMO, não fixo — o conteúdo empurra pra baixo quando precisa.
    private static let minCardHeight: CGFloat = 168
    /// Coluna de texto: sobra deliberada à direita pra a arte aparecer.
    private static let textColumnWidth: CGFloat = 230

    var body: some View {
        ZStack(alignment: .leading) {
            Image(imageAsset)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [
                            Color(red: 0.035, green: 0.036, blue: 0.045).opacity(0.98),
                            Color(red: 0.035, green: 0.036, blue: 0.045).opacity(0.88),
                            Color(red: 0.035, green: 0.036, blue: 0.045).opacity(0.30),
                            Color.clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.25),
                            Color.clear,
                            Color.black.opacity(0.32),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                    // Número em BRANCO, não no tom do tema. O ouro é da AÇÃO —
                    // quando o número também é dourado, os dois disputam e a
                    // tela deixa de ter um ponto focal.
                    Text(primary)
                        .font(PixioTypo.sans(size: 40, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.86)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .lineLimit(1)
                        // Odometro — ver StudyHeroStat: o digito rola pro lado que o
                        // numero andou, e `monospacedDigit` trava a largura da coluna.
                        .monospacedDigit()
                        .contentTransition(.numericText(value: primaryValue ?? 0))
                        .animation(.snappy(duration: 0.42), value: primaryValue)
                        .minimumScaleFactor(0.55)
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 2)

                    Text(primaryCaption)
                        .font(PixioTypo.caption)
                        .foregroundStyle(Color.white.opacity(0.62))
                        .lineLimit(1)
                }
                // Largura do bloco de texto: deixa a ilustração respirar à
                // direita sem o texto passar por cima dela.
                .frame(maxWidth: Self.textColumnWidth, alignment: .leading)

                HStack(alignment: .bottom, spacing: VitaTokens.Spacing.md) {
                    statsRow
                    Spacer(minLength: VitaTokens.Spacing.sm)
                    if let action { actionButton(action) }
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.lg)
        }
        // 🚨 minHeight, NÃO height (Rafael 2026-07-20: "repare onde estão os
        // números do hero" — as estatísticas apareciam cortadas na borda).
        // Altura CRAVADA com conteúdo variável sempre corta: bastou o número
        // passar de 19.862 pra 118.751 e ganhar mais um dígito, ou o rótulo
        // "de acerto" ser mais longo que "acerto", pra estourar os 160pt. Com
        // altura mínima o card cresce o quanto precisar e nada é engolido.
        .frame(minHeight: Self.minCardHeight, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.xl, style: .continuous))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: VitaTokens.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.13), .clear],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.14)
                    )
                )
                .frame(height: 14)
                .padding(.horizontal, 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.xl, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            theme.primary.opacity(0.12),
                            Color.white.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: theme.primary.opacity(0.12), radius: 16, x: 0, y: 7)
        .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 5)
    }

    // MARK: - Estatísticas de apoio
    //
    // Texto puro separado por um fio, sem cápsula. Elas são informação
    // SECUNDÁRIA e precisam recuar: embrulhada em cápsula, cada uma ganhava
    // peso de bloco e três blocos iguais competiam com o número.
    private var statsRow: some View {
        HStack(alignment: .center, spacing: VitaTokens.Spacing.md) {
            ForEach(Array(stats.prefix(2).enumerated()), id: \.element.id) { index, stat in
                if index > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 1, height: 26)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(stat.value)
                        .font(PixioTypo.sans(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.94))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(stat.label)
                        .font(PixioTypo.micro)
                        .foregroundStyle(Color.white.opacity(0.46))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Ação principal
    //
    // O ÚNICO elemento tátil do card, e por isso o único com matéria física:
    // gradiente (pega luz de cima), brilho especular no topo (reflexo) e halo
    // quente por baixo (elevação). Texto e números ficam planos de propósito.
    private func actionButton(_ action: Action) -> some View {
        Button(action: action.handler) {
            HStack(spacing: 6) {
                if action.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(VitaColors.surface)
                } else {
                    Text(action.title)
                        .font(PixioTypo.sans(size: 15, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))  // ds-allow: chevron do CTA
                }
            }
            .foregroundStyle(VitaColors.surface)
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [theme.primaryLight, theme.primary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(
                // Reflexo no topo: o que faz a pílula parecer sólida sob luz.
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(color: theme.primary.opacity(0.45), radius: 12, y: 4)
            .shadow(color: .black.opacity(0.30), radius: 6, y: 2)
            .opacity(action.isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!action.isEnabled || action.isLoading)
    }
}

// MARK: - Subject chip strip (themed selected state)

/// Lightweight row used by `StudySubjectChips` — decoupled from any specific
/// API response (GradeSubject, StudyOverviewSubject, etc.) so the shell only
/// depends on the canonical SOT (AppDataManager.gradesResponse) upstream.
struct StudySubjectChipItem: Identifiable, Hashable {
    let id: String
    let name: String
}

/// Horizontal chip strip for subject selection. Unified across StudySuite.
/// Tapping "Todas" clears the filter (nil selection). The selected chip uses
/// the shell's theme primary so Questões chips read orange, Flashcards
/// purple, etc. — no more gold leaking onto a purple shell.
struct StudySubjectChips: View {
    let subjects: [StudySubjectChipItem]
    @Binding var selectedId: String?
    /// Optional trailing label for the "all" chip. Defaults to "Todas".
    var allLabel: String = "Todas"
    /// Theme drives the selected chip fill + stroke. Defaults to Questões.
    var theme: StudyShellTheme = .questoes

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: allLabel, isSelected: selectedId == nil) {
                    selectedId = nil
                }
                ForEach(subjects) { subject in
                    chip(label: shortLabel(for: subject.name), isSelected: selectedId == subject.id) {
                        selectedId = subject.id
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    isSelected
                        ? Color.white.opacity(0.95)
                        : VitaColors.textSecondary
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [theme.primary, theme.primary.opacity(0.75)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(VitaColors.glassBg)
                    )
                )
                .overlay(
                    Capsule().stroke(
                        isSelected
                            ? theme.primaryLight.opacity(0.70)
                            : VitaColors.glassBorder,
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: isSelected ? theme.primary.opacity(0.35) : .clear,
                    radius: 8, y: 3
                )
        }
        .buttonStyle(.plain)
    }

    /// Shorten long subject names so chips don't blow up the row.
    /// Keeps first two significant words, preserves roman-numeral suffix.
    private func shortLabel(for name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: ",", with: "")
            .split(separator: " ")
            .map(String.init)
        guard cleaned.count > 2 else { return name.capitalized(with: .init(identifier: "pt_BR")) }
        let head = cleaned.prefix(2).joined(separator: " ")
        if let last = cleaned.last, ["I", "II", "III", "IV", "V"].contains(last.uppercased()) {
            return (head + " " + last).capitalized(with: .init(identifier: "pt_BR"))
        }
        return head.capitalized(with: .init(identifier: "pt_BR"))
    }
}
