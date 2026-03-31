import SwiftUI

// MARK: - Notifications Content

struct NotificationsStep: View {
    var body: some View {
        VStack(spacing: 16) {
            NotifFeature(icon: "bell.badge", title: String(localized: "onboarding_notif_exams"), desc: String(localized: "onboarding_notif_exams_desc"))
            NotifFeature(icon: "rectangle.stack", title: String(localized: "onboarding_notif_flashcards"), desc: String(localized: "onboarding_notif_flashcards_desc"))
            NotifFeature(icon: "chart.line.uptrend.xyaxis", title: String(localized: "onboarding_notif_weekly"), desc: String(localized: "onboarding_notif_weekly_desc"))

            Text(String(localized: "onboarding_notif_disclaimer"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
}

private struct NotifFeature: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(VitaColors.accent)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(VitaColors.accent.opacity(0.1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                Text(desc).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
        )
    }
}
