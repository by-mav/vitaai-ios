import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    var size: CGFloat = 80
    var strokeWidth: CGFloat = 8
    var trackColor: Color = VitaColors.surfaceBorder
    var progressColor: Color = VitaColors.accent

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            // Progress
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(progressColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
