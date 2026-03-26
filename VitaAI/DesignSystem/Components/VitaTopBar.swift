import SwiftUI

struct VitaTopBar: View {
    var userName: String?
    var userImageURL: URL?
    var userLevel: Int = 7
    var xpProgress: Double = 0.70
    var periodText: String = "5o periodo - Medicina"
    var onAvatarTap: (() -> Void)?
    var onNotificationTap: (() -> Void)?
    var onMenuTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar circle
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.6), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: xpProgress)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(String((userName ?? "R").prefix(1)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 40, height: 40)
            .onTapGesture { onAvatarTap?() }

            // Greeting
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(periodText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            // Notification button
            Button(action: { onNotificationTap?() }) {
                Image(systemName: "bell")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }

            // Menu button
            Button(action: { onMenuTap?() }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.1, green: 0.07, blue: 0.05).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = userName?.split(separator: " ").first.map(String.init) ?? "Rafael"
        if hour < 12 { return "Bom dia, \(name)" }
        if hour < 18 { return "Boa tarde, \(name)" }
        return "Boa noite, \(name)"
    }
}
