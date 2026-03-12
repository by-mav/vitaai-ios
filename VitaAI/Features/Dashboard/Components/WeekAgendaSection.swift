import SwiftUI

struct WeekAgendaSection: View {
    let days: [WeekDay]
    var todayEvents: [AgendaEvent] = []

    var body: some View {
        VStack(spacing: 0) {
            // Week strip — 7 dias, igual ao mockup .week
            HStack(spacing: 0) {
                ForEach(days) { day in
                    VStack(spacing: 4) {
                        Text(day.label.uppercased())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(
                                day.isToday
                                    ? Color.white.opacity(0.55)
                                    : Color.white.opacity(0.40)
                            )

                        Text("\(day.date.dayOfMonth)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                day.isToday
                                    ? Color.white.opacity(0.95)
                                    : Color.white.opacity(0.70)
                            )

                        // Dot indicator
                        Circle()
                            .fill(
                                day.isToday
                                    ? Color(red: 220/255, green: 170/255, blue: 120/255).opacity(0.70)
                                    : VitaColors.accent.opacity(day.events.isEmpty ? 0 : 0.40)
                            )
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        day.isToday
                            ? VitaColors.accent.opacity(0.12)
                            : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                day.isToday
                                    ? VitaColors.accent.opacity(0.15)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, todayEvents.isEmpty ? 0 : 12)

            // Eventos do dia dentro de glass card (glassmorphism: material + tint layer)
            if !todayEvents.isEmpty {
                VStack(spacing: 0) {
                    ForEach(todayEvents) { event in
                        HStack(spacing: 10) {
                            // All agenda icons are gold per mockup (.agenda-ico gold themed)
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(VitaColors.accent.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(VitaColors.accent.opacity(0.08), lineWidth: 1)
                                    )
                                    .frame(width: 28, height: 28)
                                Image(systemName: event.colorTag.iconName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(VitaColors.accent.opacity(0.85))
                            }

                            Text(event.title)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.65))
                                .lineLimit(1)

                            Spacer()

                            Text(event.time)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.40))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                }
                // Glass: material blur + rgba tint + border (matches mockup .glass-sm)
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
                // Inset top shimmer
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.06), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.top, 0.5)
                }
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - AgendaEventColor helpers
extension AgendaEventColor {
    var backgroundColor: Color {
        switch self {
        case .green:  return Color(red: 130/255, green: 200/255, blue: 140/255).opacity(0.15)
        case .blue:   return Color(red: 130/255, green: 160/255, blue: 220/255).opacity(0.15)
        case .orange: return Color(red: 220/255, green: 170/255, blue: 120/255).opacity(0.15)
        case .gold:   return VitaColors.accent.opacity(0.15)
        }
    }

    var iconColor: Color {
        switch self {
        case .green:  return Color(red: 130/255, green: 200/255, blue: 140/255).opacity(0.80)
        case .blue:   return Color(red: 130/255, green: 160/255, blue: 220/255).opacity(0.80)
        case .orange: return Color(red: 220/255, green: 170/255, blue: 120/255).opacity(0.80)
        case .gold:   return VitaColors.accent.opacity(0.80)
        }
    }

    var iconName: String {
        switch self {
        case .green:  return "book.fill"
        case .blue:   return "person.2.fill"
        case .orange: return "stethoscope"
        case .gold:   return "star.fill"
        }
    }
}
