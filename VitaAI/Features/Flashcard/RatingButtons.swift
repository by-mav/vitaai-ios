import SwiftUI

// MARK: - Rating option descriptor

private struct RatingOption {
    let rating: ReviewRating
    let label: String
    let icon: String              // SF Symbol name
    let color: Color
    let bgColor: Color
    let borderColor: Color
    var intervalLabel: String = ""
}

// MARK: - RatingButtonsView

/// Four rating buttons (Again / Hard / Good / Easy) matching Android / web design.
/// Each button shows a color-coded label, icon, and the SM-2 interval preview.
struct RatingButtonsView: View {

    let intervalPreviews: [ReviewRating: Int]
    var onRate: (ReviewRating) -> Void

    // Data colors — match mockup flashcard-session-v1.html rating buttons
    // Errei=red, Difícil=amber, Bom=purple, Fácil=green
    private let colorAgain = Color(red: 255/255, green: 120/255, blue: 80/255)    // rgba(255,120,80)
    private let colorHard  = Color(red: 245/255, green: 180/255, blue: 60/255)    // rgba(245,180,60)
    private let colorGood  = Color(red: 180/255, green: 120/255, blue: 255/255)   // rgba(180,120,255) — purple!
    private let colorEasy  = Color(red: 130/255, green: 200/255, blue: 140/255)   // rgba(130,200,140)

    private func options() -> [RatingOption] {
        let fmt = FsrsScheduler.formatInterval

        // Background colors match mockup btn-resp classes (deep dark tinted glass)
        return [
            RatingOption(
                rating: .again,
                label: ReviewRating.again.label,
                icon: "arrow.counterclockwise",
                color: colorAgain,
                bgColor: Color(red: 30/255, green: 12/255, blue: 12/255).opacity(0.88),
                borderColor: Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.18),
                intervalLabel: fmt(intervalPreviews[.again] ?? 0)
            ),
            RatingOption(
                rating: .hard,
                label: ReviewRating.hard.label,
                icon: "chevron.down",
                color: colorHard,
                bgColor: Color(red: 24/255, green: 16/255, blue: 8/255).opacity(0.88),
                borderColor: Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.18),
                intervalLabel: fmt(intervalPreviews[.hard] ?? 1)
            ),
            RatingOption(
                rating: .good,
                label: ReviewRating.good.label,
                icon: "checkmark",
                color: colorGood,
                bgColor: Color(red: 16/255, green: 10/255, blue: 20/255).opacity(0.88),
                borderColor: Color(red: 148/255, green: 75/255, blue: 220/255).opacity(0.18),
                intervalLabel: fmt(intervalPreviews[.good] ?? 3)
            ),
            RatingOption(
                rating: .easy,
                label: ReviewRating.easy.label,
                icon: "bolt.fill",
                color: colorEasy,
                bgColor: Color(red: 8/255, green: 20/255, blue: 14/255).opacity(0.88),
                borderColor: Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.18),
                intervalLabel: fmt(intervalPreviews[.easy] ?? 7)
            ),
        ]
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options(), id: \.rating) { option in
                RatingButton(option: option) {
                    onRate(option.rating)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: intervalPreviews.count)
    }
}

// MARK: - Single Rating Button

private struct RatingButton: View {

    let option: RatingOption
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            triggerHaptic()
            onTap()
        }) {
            VStack(spacing: 4) {
                // Label (matches mockup .btn-label: 13px semibold)
                Text(option.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(option.color.opacity(0.85))

                // Interval (matches mockup .btn-time: 10px)
                if !option.intervalLabel.isEmpty {
                    Text(option.intervalLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(option.color.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(option.bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(option.borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 5)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PressButtonStyle(isPressed: $isPressed))
        .accessibilityLabel("\(option.label), \(option.intervalLabel)")
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Custom Button Style for press tracking

private struct PressButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { pressed in
                isPressed = pressed
            }
    }
}
