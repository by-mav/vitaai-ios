import SwiftUI

// MARK: - VitaHeroCard
//
// Hero card padronizado para o app: fundo com imagem (lado direito visível via
// gradient left→right), label pill, título, subtítulo opcional, stats pills e
// CTA. Mesmo padrão visual que o Dashboard usa nos cards server-driven, agora
// reutilizável para Progresso, Faculdade-detalhe, etc.
//
// Uso:
//   VitaHeroCard(
//       label: "NÍVEL 1",
//       title: "Faltam 309 XP pra subir",
//       progress: 0.09,
//       stats: [("30 XP total", nil), ("Streak 0", nil)],
//       cta: "Ver ranking",
//       bgImage: "fundo-dashboard",
//       action: { ... }
//   )
//
// Zero SF Symbol decorativo. Se stat.icon == nil, não renderiza ícone.

struct VitaHeroCard: View {
    let label: String
    var labelColor: Color = VitaColors.accentHover
    let title: String
    var subtitle: String? = nil
    /// 0.0..1.0 — se não nil, desenha barra de progresso entre subtitle e stats.
    var progress: Double? = nil
    /// Stats exibidos como pills. Se icon == nil, mostra apenas texto.
    var stats: [(text: String, icon: String?)] = []
    let cta: String
    let bgImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                Image(bgImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.031, green: 0.024, blue: 0.016).opacity(0.88), location: 0),
                        .init(color: Color(red: 0.031, green: 0.024, blue: 0.016).opacity(0.50), location: 0.45),
                        .init(color: Color(red: 0.031, green: 0.024, blue: 0.016).opacity(0.15), location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )

                VStack(alignment: .leading, spacing: 10) {
                    Spacer()

                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(labelColor.opacity(0.75))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(labelColor.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(labelColor.opacity(0.16), lineWidth: 1))
                        )

                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.04 * 20)
                        .lineLimit(2)
                        .foregroundStyle(Color(red: 1, green: 0.988, blue: 0.973).opacity(0.97))

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .lineLimit(1)
                    }

                    if let progress {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 5)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                VitaColors.accent.opacity(0.85),
                                                VitaColors.accentHover.opacity(0.60)
                                            ],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * min(max(progress, 0), 1), height: 5)
                            }
                        }
                        .frame(height: 5)
                    }

                    if !stats.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(stats.prefix(3).enumerated()), id: \.offset) { _, s in
                                heroPill(text: s.text, icon: s.icon)
                            }
                        }
                    }

                    Text(cta)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.24)
                        .foregroundStyle(Color(red: 1, green: 0.902, blue: 0.706).opacity(0.80))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.accentHover.opacity(0.12), lineWidth: 1))
                        )
                }
                .padding(16)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: VitaColors.accentHover.opacity(0.40), location: 0.0),
                                .init(color: VitaColors.accentHover.opacity(0.12), location: 0.19),
                                .init(color: Color.white.opacity(0.04), location: 0.33),
                                .init(color: Color.white.opacity(0.025), location: 0.50),
                                .init(color: Color.white.opacity(0.04), location: 0.64),
                                .init(color: VitaColors.accentHover.opacity(0.12), location: 0.78),
                                .init(color: VitaColors.accentHover.opacity(0.40), location: 1.0),
                            ]),
                            center: UnitPoint(x: 0.4, y: 0.8)
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.50), radius: 28, x: 0, y: 11)
            .shadow(color: Color(red: 0.706, green: 0.549, blue: 0.235).opacity(0.08), radius: 22, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func heroPill(text: String, icon: String?) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.accentHover.opacity(0.70))
            }
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.60))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }
}
