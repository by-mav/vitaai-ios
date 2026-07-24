import SwiftUI

// MARK: - Filtro da Jornada
//
// UM botão no lugar do perfil abre UM sheet (Rafael 2026-07-23). A versão
// anterior era uma fileira permanente de botões soltos em cima do jogo — ele
// resumiu como "a coisa mais feia que eu já vi na minha vida", com razão: o
// mundo da trilha não aceita chrome de app empilhado por cima.
//
// Escolher aqui NÃO muda o mapa. Muda o que o tile dispara. Sem escolha =
// medicina inteira, que é o padrão de propósito.
//
// Arte: VitaEmblem, o componente canônico — a LEI de 2026-07-02 já proibia PNG
// de IA pra ícone. A peça de ouro é IDÊNTICA nas seis; só muda o símbolo
// gravado. Por isso nunca saem de tamanhos diferentes.

/// As 6 grandes áreas, na ordem canônica do backend (`examGreatAreaSlug`).
enum GrandeArea: String, CaseIterable, Identifiable {
    case cicloBasico = "ciclo-basico"
    case clinicaMedica = "clinica-medica"
    case cirurgiaGeral = "cirurgia-geral"
    case ginecologiaObstetricia = "ginecologia-obstetricia"
    case pediatria = "pediatria"
    case preventivaSocial = "medicina-preventiva-social"

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .cicloBasico: return "Ciclo Básico"
        case .clinicaMedica: return "Clínica Médica"
        case .cirurgiaGeral: return "Cirurgia"
        case .ginecologiaObstetricia: return "Gineco e Obstetrícia"
        case .pediatria: return "Pediatria"
        case .preventivaSocial: return "Preventiva e Social"
        }
    }

    /// Símbolo gravado no emblema. Todos conferidos contra a lista do sistema
    /// (`CoreGlyphs.bundle/symbol_order.plist`) — nome errado renderiza vazio.
    var simbolo: String {
        switch self {
        case .cicloBasico: return "testtube.2"
        case .clinicaMedica: return "stethoscope"
        case .cirurgiaGeral: return "facemask.fill"
        case .ginecologiaObstetricia: return "figure.and.child.holdinghands"
        case .pediatria: return "teddybear.fill"
        case .preventivaSocial: return "person.3.fill"
        }
    }
}

/// Disciplina como o seletor precisa dela.
struct DisciplinaDaArea: Identifiable, Equatable {
    let slug: String
    let nome: String
    var acerto: Double?
    var id: String { slug }
}

// MARK: - O botão que fica no lugar do perfil


// MARK: - O sheet

struct JornadaFiltroSheet: View {
    @Binding var area: GrandeArea?
    @Binding var disciplina: String?
    let disciplinas: [DisciplinaDaArea]
    var aoFechar: () -> Void

    var body: some View {
        VitaSheet(title: "O que você quer estudar") {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xl) {
                Text("Isso não muda o mapa — muda o que abre quando você toca numa etapa. Sem escolher nada, vale medicina inteira.")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: VitaTokens.Spacing.md), count: 3),
                          spacing: VitaTokens.Spacing.lg) {
                    ForEach(GrandeArea.allCases) { a in
                        botaoArea(a)
                    }
                }

                if area != nil {
                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
                        Text("DISCIPLINAS")
                            .font(VitaTypography.labelSmall)
                            .tracking(VitaTokens.Typography.letterSpacingWide)
                            .foregroundStyle(VitaColors.textTertiary)

                        if disciplinas.isEmpty {
                            Text("Nenhuma disciplina desta área no seu currículo ainda.")
                                .font(VitaTypography.bodySmall)
                                .foregroundStyle(VitaColors.textTertiary)
                        } else {
                            FluxoDeChips(disciplinas: disciplinas, selecionada: $disciplina)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                VitaButton(text: "Pronto", action: aoFechar)
            }
            .animation(.easeOut(duration: VitaTokens.Animation.durationNormal), value: area)
        }
    }

    @ViewBuilder
    private func botaoArea(_ a: GrandeArea) -> some View {
        let ativa = area == a
        Button {
            // Tocar na área ativa DESLIGA o filtro: é como se volta pra
            // "medicina inteira" sem gastar espaço com um botão "tudo".
            area = ativa ? nil : a
            disciplina = nil
        } label: {
            VStack(spacing: VitaTokens.Spacing.sm) {
                VitaEmblem(symbol: a.simbolo, size: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 54 * 0.30, style: .continuous)  // ds-allow: acompanha o canto do VitaEmblem (size * 0.30) — token nao encaixa
                            .strokeBorder(VitaColors.accent, lineWidth: 2.5)
                            .opacity(ativa ? 1 : 0)
                    )
                    .opacity(area == nil || ativa ? 1 : 0.42)
                    .scaleEffect(ativa ? 1.06 : 1)

                Text(a.nome)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(ativa ? VitaColors.textPrimary : VitaColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 26, alignment: .top)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("area_\(a.rawValue)")
        .accessibilityAddTraits(ativa ? .isSelected : [])
    }
}

/// Chips que quebram linha. Disciplina não cabe em fileira: Pediatria tem 24.
private struct FluxoDeChips: View {
    let disciplinas: [DisciplinaDaArea]
    @Binding var selecionada: String?

    var body: some View {
        FlowLayout(spacing: VitaTokens.Spacing.sm) {
            ForEach(disciplinas) { d in
                let ativa = selecionada == d.slug
                Button {
                    selecionada = ativa ? nil : d.slug
                } label: {
                    HStack(spacing: VitaTokens.Spacing.xs) {
                        Text(d.nome)
                            .font(VitaTypography.labelMedium)
                        if let acerto = d.acerto {
                            Text("\(Int(acerto * 100))%")
                                .font(VitaTypography.labelSmall)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, VitaTokens.Spacing.md)
                    .padding(.vertical, VitaTokens.Spacing.sm)
                    .foregroundStyle(ativa ? VitaColors.surface : VitaColors.textSecondary)
                    .background(Capsule().fill(ativa ? VitaColors.accent
                                                     : VitaColors.surfaceCard.opacity(0.8)))
                    .overlay(Capsule().strokeBorder(VitaColors.glassBorder,
                                                    lineWidth: ativa ? 0 : 0.75))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("disciplina_\(d.slug)")
            }
        }
    }
}

