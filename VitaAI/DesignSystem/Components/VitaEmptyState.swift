import SwiftUI

// MARK: - VitaEmptyState

/// Empty state placeholder for screens with no data.
///
/// Centered layout with:
/// - Optional icon (any View — Image, SF Symbol, Lottie wrapper, etc.)
/// - Title and descriptive message
/// - Optional action button (uses VitaButton .secondary)
/// - Gentle fade-in animation on first appearance
///
/// Usage:
/// ```swift
/// VitaEmptyState(
///     title: "Nenhum registro",
///     message: "Adicione seu primeiro item para começar.",
///     actionText: "Adicionar",
///     onAction: { showAddSheet = true }
/// )
/// ```
struct VitaEmptyState<Icon: View>: View {
    let title: String
    let message: String
    var actionText: String? = nil
    var onAction: (() -> Void)? = nil
    @ViewBuilder var icon: () -> Icon

    @State private var visible = false

    var body: some View {
        VStack(spacing: 0) {
            icon()
                .padding(.bottom, 24)

            Text(title)
                .font(VitaTypography.titleMedium)
                .foregroundColor(VitaColors.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            Text(message)
                .font(VitaTypography.bodyMedium)
                .foregroundColor(VitaColors.textSecondary)
                .multilineTextAlignment(.center)

            if let text = actionText, let action = onAction {
                Spacer().frame(height: 24)
                VitaButton(text: text, action: action, variant: .secondary, size: .md)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 48)
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                visible = true
            }
        }
    }
}

// MARK: - Convenience init (no icon)

extension VitaEmptyState where Icon == EmptyView {
    init(
        title: String,
        message: String,
        actionText: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.actionText = actionText
        self.onAction = onAction
        self.icon = { EmptyView() }
    }
}

// MARK: - Convenience: with VitaSpeakingMascot (Duolingo pattern)

/// Factory pra empty/error state com mascote contextual. Substitui o
/// "Nenhum X ainda" + ícone genérico SF Symbol — Rafael 2026-04-25 pediu
/// pra mascote aparecer em sub-telas educativas (estilo Duolingo).
///
/// Uso:
/// ```swift
/// VitaEmptyState.mascot(
///     persona: .studying(prop: .book),
///     title: "Sem flashcards ainda",
///     message: "Conecte o portal e eu gero baralhos.",
///     actionText: "Conectar",
///     onAction: { ... },
///     userName: authManager.userName
/// )
/// ```
extension VitaEmptyState where Icon == VitaSpeakingMascot {
    static func mascot(
        persona: MascotPersona = .studying(),
        title: String,
        message: String,
        actionText: String? = nil,
        onAction: (() -> Void)? = nil,
        userName: String? = nil,
        mascotSize: CGFloat = 96
    ) -> VitaEmptyState<VitaSpeakingMascot> {
        VitaEmptyState<VitaSpeakingMascot>(
            title: title,
            message: message,
            actionText: actionText,
            onAction: onAction,
            icon: {
                VitaSpeakingMascot(
                    persona: persona,
                    size: mascotSize,
                    speech: nil,
                    userName: userName
                )
            }
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VitaEmptyState") {
    ZStack {
        VitaColors.surface.ignoresSafeArea()
        VStack {
            VitaEmptyState(
                title: "Nenhuma consulta",
                message: "Você ainda não tem consultas agendadas. Comece agendando uma.",
                actionText: "Agendar consulta",
                onAction: {}
            ) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(VitaColors.accent)
            }
        }
    }
}
#endif
