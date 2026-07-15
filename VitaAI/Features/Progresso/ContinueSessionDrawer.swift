import Observation
import SwiftUI

@MainActor
@Observable
final class ActiveStudySessionsViewModel {
    private let api: VitaAPI

    private(set) var sessions: [ActiveStudySession] = []
    private(set) var finishingIds: Set<String> = []
    private(set) var errorMessage: String?

    init(api: VitaAPI) {
        self.api = api
    }

    func refresh() async {
        do {
            sessions = try await api.getActiveStudySessions().sessions
            errorMessage = nil
        } catch {
            errorMessage = "Não foi possível carregar suas sessões."
            NSLog("[ActiveStudySessions] refresh failed: %@", String(describing: error))
        }
    }

    func finish(_ session: ActiveStudySession) async {
        guard !finishingIds.contains(session.id) else { return }
        finishingIds.insert(session.id)
        defer { finishingIds.remove(session.id) }

        do {
            switch session.engine {
            case .qbank:
                _ = try await api.finishQBankSession(id: session.id)
            case .simulado:
                _ = try await api.finishSimulado(attemptId: session.id, timeTakenMs: 0)
            case .flashcards:
                _ = try await api.finishFlashcardStudySession(id: session.id)
            }
            sessions.removeAll { $0.id == session.id && $0.engine == session.engine }
            errorMessage = nil
        } catch {
            errorMessage = "Não foi possível encerrar a sessão."
            NSLog("[ActiveStudySessions] finish failed: %@", String(describing: error))
        }
    }
}

struct ContinueSessionDrawer: View {
    let model: ActiveStudySessionsViewModel
    let onResume: (ActiveStudySession) -> Void

    @State private var isExpanded = false

    private var primary: ActiveStudySession? { model.sessions.first }

    var body: some View {
        if let primary {
            Group {
                if isExpanded {
                    expandedDrawer
                        .frame(width: 320)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topLeading)))
                } else {
                    collapsedDrawer(primary)
                        .frame(width: 220)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                }
            }
            .animation(.easeOut(duration: 0.20), value: isExpanded)
            .accessibilityIdentifier("continueSessionDrawer")
            .onChange(of: model.sessions.count) { _, count in
                if count == 0 { isExpanded = false }
            }
        }
    }

    private func collapsedDrawer(_ session: ActiveStudySession) -> some View {
        Button {
            PixioHaptics.tap()
            isExpanded = true
        } label: {
            VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                HStack(spacing: VitaTokens.Spacing.md) {
                    sessionIcon(session, size: 30)

                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                        Text("Continuar sessão")
                            .font(VitaTypography.labelLarge)
                            .foregroundStyle(VitaColors.textPrimary)
                        Text(progressText(session))
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                            .monospacedDigit()
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold)) // ds-allow: tamanho óptico do SF Symbol
                        .foregroundStyle(VitaColors.accentLight.opacity(0.72))
                }
                .padding(.horizontal, VitaTokens.Spacing.md)
                .frame(height: 48)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continuar sessão, \(session.title), \(progressText(session))")
        .accessibilityHint("Abre suas sessões em andamento")
    }

    private var expandedDrawer: some View {
        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
            VStack(spacing: 0) {
                HStack(spacing: VitaTokens.Spacing.sm) {
                    Text("Sessões em andamento")
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)

                    Spacer()

                    Button {
                        isExpanded = false
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold)) // ds-allow: tamanho óptico do SF Symbol
                            .foregroundStyle(VitaColors.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Recolher")
                }
                .padding(.leading, VitaTokens.Spacing.lg)
                .padding(.trailing, VitaTokens.Spacing.sm)
                .frame(height: 44)

                Rectangle()
                    .fill(VitaColors.glassBorder.opacity(0.72))
                    .frame(height: 0.5)

                VStack(spacing: VitaTokens.Spacing.xs) {
                    ForEach(Array(model.sessions.prefix(4))) { session in
                        sessionRow(session)
                    }
                }
                .padding(VitaTokens.Spacing.sm)
            }
        }
    }

    private func sessionRow(_ session: ActiveStudySession) -> some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Button {
                PixioHaptics.tap()
                isExpanded = false
                onResume(session)
            } label: {
                HStack(spacing: VitaTokens.Spacing.md) {
                    sessionIcon(session, size: 34)

                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                        Text(session.title)
                            .font(VitaTypography.labelLarge)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(VitaColors.textPrimary.opacity(0.08))
                                Capsule()
                                    .fill(VitaColors.accent)
                                    .frame(width: geometry.size.width * progress(session))
                            }
                        }
                        .frame(height: 3)

                        Text(progressText(session))
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                            .monospacedDigit()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resumeSession_\(session.engine.rawValue)_\(session.id)")
            .accessibilityLabel("Continuar \(session.title), \(progressText(session))")

            Menu {
                Button(role: .destructive) {
                    Task { await model.finish(session) }
                } label: {
                    Label("Encerrar sessão", systemImage: "xmark.circle")
                }
            } label: {
                if model.finishingIds.contains(session.id) {
                    ProgressView()
                        .tint(VitaColors.accent)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold)) // ds-allow: tamanho óptico do SF Symbol
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
            .frame(width: 40, height: 44)
            .accessibilityLabel("Opções de \(session.title)")
        }
        .padding(.leading, VitaTokens.Spacing.sm)
        .padding(.trailing, VitaTokens.Spacing.xs)
        .frame(minHeight: 62)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(VitaColors.textPrimary.opacity(0.035))
        )
    }

    private func sessionIcon(_ session: ActiveStudySession, size: CGFloat) -> some View {
        Image(systemName: iconName(session.kind))
            .font(.system(size: size * 0.42, weight: .semibold)) // ds-allow: ícone escala com o container
            .foregroundStyle(VitaColors.accentLight)
            .frame(width: size, height: size)
            .background(Circle().fill(VitaColors.accentSubtle))
            .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 0.75))
    }

    private func progress(_ session: ActiveStudySession) -> CGFloat {
        guard session.total > 0 else { return 0 }
        return min(1, max(0, CGFloat(session.current) / CGFloat(session.total)))
    }

    private func progressText(_ session: ActiveStudySession) -> String {
        let current = min(max(0, session.current), max(0, session.total))
        return "\(current) de \(session.total) · \(kindLabel(session.kind))"
    }

    private func kindLabel(_ kind: ActiveStudySessionKind) -> String {
        switch kind {
        case .questoes: return "Questões"
        case .simulado: return "Simulado"
        case .flashcards: return "Flashcards"
        }
    }

    private func iconName(_ kind: ActiveStudySessionKind) -> String {
        switch kind {
        case .questoes: return "checklist"
        case .simulado: return "doc.text.magnifyingglass"
        case .flashcards: return "rectangle.on.rectangle.angled"
        }
    }
}
