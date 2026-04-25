import SwiftUI

/// Loading state com a personalidade do Vita: o mascote (orb) flutua
/// pequeno no centro e um coração dourado pulsa "dentro" dele em
/// ritmo lub-dub — diástole curta seguida de uma sístole mais lenta,
/// que é o ciclo cardíaco real (~70 bpm). Diferente do `OrbMascot` puro
/// usado no onboarding, esta view diz claramente "carregando" sem
/// poluir a tela com texto.
struct VitaHeartbeatLoader: View {
    var orbSize: CGFloat = 96

    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            OrbMascot(palette: .vita, state: .awake, size: orbSize, bounceEnabled: false)

            Image(systemName: "heart.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: orbSize * 0.34)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.86, blue: 0.55),
                            Color(red: 0.94, green: 0.65, blue: 0.27)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 1.0, green: 0.78, blue: 0.36).opacity(0.55), radius: 10)
                .scaleEffect(heartScale)
                .offset(y: orbSize * 0.04)
        }
        .onAppear { animate() }
    }

    /// Lub-dub: pulse forte (sístole) seguido de pulse curto (diástole),
    /// pausa diastólica, repete. ~0.86s por ciclo ≈ 70 bpm.
    private func animate() {
        Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.16)) { heartScale = 1.18 }
                try? await Task.sleep(nanoseconds: 160_000_000)
                withAnimation(.easeIn(duration: 0.14)) { heartScale = 1.0 }
                try? await Task.sleep(nanoseconds: 180_000_000)
                withAnimation(.easeOut(duration: 0.13)) { heartScale = 1.10 }
                try? await Task.sleep(nanoseconds: 130_000_000)
                withAnimation(.easeIn(duration: 0.13)) { heartScale = 1.0 }
                try? await Task.sleep(nanoseconds: 260_000_000)
            }
        }
    }
}

#Preview {
    ZStack {
        VitaColors.surface.ignoresSafeArea()
        VitaHeartbeatLoader()
    }
}
