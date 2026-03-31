import SwiftUI
import Charts

/// Donut chart (SectorMark, iOS 17+) showing the distribution of flashcard states:
/// Novo / Aprendendo / Revisão / Dominado.
struct CardDistributionDonutView: View {
    // SectorMark requires iOS 17+
    let categories: [CardCategory]

    private var totalCards: Int {
        categories.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            donutBody
        } else {
            // Fallback: simple list for iOS 16
            fallbackBody
        }
    }
    
    @available(iOS 17.0, *)
    private var donutBody: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distribuição de Cards")
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)

                HStack(alignment: .center, spacing: 16) {
                    // Donut chart with center label
                    ZStack {
                        Chart(categories) { cat in
                            SectorMark(
                                angle: .value("Qtd", cat.count),
                                innerRadius: .ratio(0.60),
                                angularInset: 2
                            )
                            .foregroundStyle(cat.color)
                            .cornerRadius(3)
                        }
                        .frame(width: 110, height: 110)

                        // Center: total cards
                        VStack(spacing: 0) {
                            Text("\(totalCards)")
                                .font(.system(size: 20, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(VitaColors.textPrimary)
                            Text("cards")
                                .font(.system(size: 9))
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    }

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(categories) { cat in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(cat.color)
                                    .frame(width: 10, height: 10)

                                Text(cat.name)
                                    .font(VitaTypography.labelSmall)
                                    .foregroundStyle(VitaColors.textSecondary)

                                Spacer()

                                Text("\(cat.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(VitaColors.textPrimary)

                                let pct = totalCards > 0
                                    ? Int(Double(cat.count) / Double(totalCards) * 100)
                                    : 0
                                Text("(\(pct)%)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(VitaColors.textTertiary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
        }
    }
}
// MARK: - iOS 16 Fallback (no SectorMark)
extension CardDistributionDonutView {
    private var fallbackBody: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distribuição de Cards")
                    .font(VitaTypography.titleSmall)
                    .foregroundColor(VitaColors.textPrimary)
                
                ForEach(categories) { cat in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cat.color)
                            .frame(width: 10, height: 10)
                        Text(cat.name)
                            .font(VitaTypography.labelSmall)
                            .foregroundColor(VitaColors.textSecondary)
                        Spacer()
                        let pct = totalCards > 0 ? Int(Double(cat.count) / Double(totalCards) * 100) : 0
                        Text("\(cat.count) (\(pct)%)")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(VitaColors.textPrimary)
                    }
                }
                
                Text("\(totalCards) cards total")
                    .font(VitaTypography.labelSmall)
                    .foregroundColor(VitaColors.textTertiary)
            }
            .padding()
        }
    }
}
