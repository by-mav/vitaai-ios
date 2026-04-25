import SwiftUI

// MARK: - VitaCardRow
//
// Shell único pra rows de listas no Vita: notebooks, mind maps, decks,
// trabalhos, documentos, transcrições, simulados, questões.
//
// Gestos suportados (todos opcionais — passa nil pra desabilitar):
//
//   • Tap                  → onTap        (abrir o item)
//   • Long-press           → onLongPress  (menu contextual: rename, mover...)
//   • Swipe →              → onSwipeRight (favoritar — ícone fav cresce)
//   • Swipe ←              → onSwipeLeft  (excluir — ícone del cresce)
//
// O ícone Vita custom (icone-fav-vita / icone-del-vita) cresce de 32pt
// até 64pt conforme o drag se aproxima do threshold (sem stretch, scale
// natural). Sem texto, sem fundo colorido.
//
// Pattern visual: Apple Mail (swipe), Notion (long-press), Telegram.
// Validado pela Rafael (2026-04-25) na Transcrição → expandido pro shell.

struct VitaCardRow<Content: View>: View {
    /// Tap = abrir o item. nil quando o caller já adiciona `.onTapGesture`
    /// externo (ex: Transcrição usa contextMenu nativo iOS junto).
    let onTap: (() -> Void)?
    /// Long-press → menu contextual (rename, mover pra pasta, etc).
    /// Passa nil quando o caller usa `.contextMenu { }` nativo iOS direto
    /// no content, OU quando o item é imutável (ex: fonte externa).
    let onLongPress: (() -> Void)?
    /// Swipe da esquerda pra direita → favoritar. nil = desabilita o lado.
    let onSwipeRight: (() -> Void)?
    /// Swipe da direita pra esquerda → excluir. nil = desabilita o lado
    /// (ex: trabalhos do portal que o servidor controla).
    let onSwipeLeft: (() -> Void)?
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    private let actionThreshold: CGFloat = 100
    private let cornerRadius: CGFloat = 16

    init(
        onTap: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil,
        onSwipeLeft: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onSwipeRight = onSwipeRight
        self.onSwipeLeft = onSwipeLeft
        self.content = content()
    }

    /// Ícone Vita cresce de 32 → 64pt conforme arrasta.
    private var iconSize: CGFloat {
        let progress = min(abs(offset) / actionThreshold, 1.0)
        return 32 + progress * 32
    }

    var body: some View {
        ZStack {
            // Background reveal — só aparece se o lado está habilitado.
            ZStack {
                Color.clear
                if offset > 0, onSwipeRight != nil {
                    Image("icone-fav-vita")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                        .opacity(min(offset / actionThreshold, 1.0))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                } else if offset < 0, onSwipeLeft != nil {
                    Image("icone-del-vita")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                        .opacity(min(abs(offset) / actionThreshold, 1.0))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 16)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .animation(.easeOut(duration: 0.15), value: offset)

            // Card content + gestures
            content
                .offset(x: offset)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isDragging, offset == 0 else { return }
                    onTap?()
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    guard let action = onLongPress, offset == 0 else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    action()
                }
                .gesture(swipeGesture)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                isDragging = true
                let raw = value.translation.width
                // Bloqueia o lado que não tem ação configurada.
                if raw > 0, onSwipeRight == nil { offset = 0; return }
                if raw < 0, onSwipeLeft == nil { offset = 0; return }
                // Rubber band nas extremidades.
                offset = raw.magnitude > 200 ? (raw > 0 ? 200 : -200) : raw
            }
            .onEnded { value in
                isDragging = false
                let dx = value.translation.width

                if dx > actionThreshold, let action = onSwipeRight {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        action()
                        offset = 0
                    }
                } else if dx < -actionThreshold, let action = onSwipeLeft {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = -400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        action()
                        offset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        offset = 0
                    }
                }
            }
    }
}
