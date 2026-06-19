import SwiftUI

struct VitaAmbientBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            PixioAuroraBackground()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
