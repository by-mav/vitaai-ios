import SwiftUI

// MARK: - Card accent colors (purple theme from flashcard-session-v1.html mockup)

private let purpleAccent  = Color(red: 148/255, green: 75/255, blue: 220/255) // rgba(148,75,220)
private let purpleLabel   = Color(red: 180/255, green: 120/255, blue: 255/255) // rgba(180,120,255)

// Card gradient: linear-gradient(135deg, #100818 0%, #08040e 100%)
private let cardGradient  = LinearGradient(
    colors: [
        Color(red: 0x10/255, green: 0x08/255, blue: 0x18/255),
        Color(red: 0x08/255, green: 0x04/255, blue: 0x0e/255)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// MARK: - FlashcardCardView

/// Animated flip card matching flashcard-session-v1.html mockup.
/// - Front: uppercase tag, question, italic hint at bottom
/// - Back: "Resposta" tag, purple divider, answer text
struct FlashcardCardView: View {

    let front: String
    let back: String
    let deckTitle: String
    let isFlipped: Bool
    var onFlip: () -> Void

    @State private var rotationDegrees: Double = 0

    var body: some View {
        ZStack {
            frontFace
                .opacity(rotationDegrees < 90 ? 1 : 0)
                .rotation3DEffect(.degrees(rotationDegrees), axis: (0, 1, 0), perspective: 0.4)

            backFace
                .opacity(rotationDegrees >= 90 ? 1 : 0)
                .rotation3DEffect(.degrees(rotationDegrees - 180), axis: (0, 1, 0), perspective: 0.4)
        }
        .contentShape(Rectangle())
        .onTapGesture { onFlip() }
        .accessibilityLabel(isFlipped
            ? "Resposta: \(back). Toque para ver a pergunta."
            : "Flashcard: \(front). Toque para revelar a resposta."
        )
        .onChange(of: isFlipped) { flipped in
            withAnimation(.easeInOut(duration: 0.5)) {
                rotationDegrees = flipped ? 180 : 0
            }
        }
    }

    // MARK: Front face

    private var frontFace: some View {
        cardShell {
            VStack(spacing: 0) {
                // Category tag — plain uppercase text per .card-tag
                Text(deckTitle.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.0)
                    .foregroundStyle(purpleLabel.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(height: 16)

                // Question — 20px semibold, rgba(255,252,248,0.95), vertically centered
                Text(front)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(VitaColors.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .tracking(-0.4) // letter-spacing: -0.02em ≈ -0.4 at 20px
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)

                Spacer()

                // Hint — italic, rgba(255,255,255,0.18), centered at bottom
                Text("Toque para ver a resposta")
                    .font(.system(size: 11, weight: .regular).italic())
                    .foregroundStyle(Color.white.opacity(0.18))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Back face

    private var backFace: some View {
        cardShell {
            VStack(spacing: 0) {
                // "Resposta" tag — same style as front tag
                Text("RESPOSTA")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.0)
                    .foregroundStyle(purpleLabel.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Divider — 40px × 2px, rgba(148,75,220,0.25), per .card-divider
                HStack {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(purpleAccent.opacity(0.25))
                        .frame(width: 40, height: 2)
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 12)

                // Answer text — 16px medium, rgba(255,252,248,0.88)
                Text(back)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(VitaColors.white.opacity(0.88))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
        }
    }

    // MARK: Card shell — border-radius 22, gradient bg, border rgba(148,75,220,0.20)

    @ViewBuilder
    private func cardShell<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 22)
                .fill(cardGradient)

            // Border
            RoundedRectangle(cornerRadius: 22)
                .stroke(purpleAccent.opacity(0.20), lineWidth: 1)

            // Top-right glow overlay
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    RadialGradient(
                        colors: [purpleAccent.opacity(0.18), .clear],
                        center: UnitPoint(x: 0.85, y: 0.15),
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .blendMode(.normal)

            // Content
            content()
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
        }
        // Shadow approximating mockup box-shadow
        .shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 12)
        .shadow(color: purpleAccent.opacity(0.20), radius: 24, x: 0, y: 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
