import SwiftUI

// MARK: - QBankFlashcardButton — "Virar flashcard" (issue #188 I2)
//
// Botão secundário da explicação da questão: manda a questão errada pro deck
// "Questões erradas" (POST /api/study/flashcards/from-question — card
// determinístico, sem LLM; dedup server-side por sourceQuestionId).
// Estados: botão → criando → confirmação "No baralho Questões erradas"
// (criado agora OU já existia) · 422 = questão discursiva · falha = retry.

struct QBankFlashcardButton: View {
    let questionId: Int

    @Environment(\.appContainer) private var container

    private enum Phase: Equatable {
        case idle
        case creating
        case done
        case discursive
        case failed
    }
    @State private var phase: Phase = .idle

    var body: some View {
        switch phase {
        case .done:
            notice(
                icon: "checkmark.circle.fill",
                text: "No baralho Questões erradas",
                tint: VitaColors.dataGreen
            )
        case .discursive:
            notice(
                icon: "info.circle",
                text: "Questão discursiva não vira flashcard",
                tint: VitaColors.textTertiary
            )
        case .idle, .creating, .failed:
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                button
                if phase == .failed {
                    Text("Não foi possível criar o flashcard. Tenta de novo.")
                        .font(PixioTypo.caption)
                        .foregroundStyle(VitaColors.dataRed)
                }
            }
        }
    }

    private var button: some View {
        Button(action: create) {
            HStack(spacing: VitaTokens.Spacing.sm) {
                if phase == .creating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(VitaColors.accentLight)
                } else {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 14, weight: .semibold))  // ds-allow: ícone do botão (par com o texto)
                }
                Text("Virar flashcard")
                    .font(PixioTypo.sans(size: 15, weight: .semibold))
            }
            .foregroundStyle(VitaColors.accentLight)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .fill(VitaColors.glassBg.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                    .stroke(VitaColors.accent.opacity(0.34), lineWidth: 0.9)
            )
            .contentShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(phase == .creating)
    }

    private func notice(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))  // ds-allow: ícone da confirmação (par com o texto)
                .foregroundStyle(tint)
            Text(text)
                .font(PixioTypo.sans(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 0.75)
        )
        .transition(.opacity)
    }

    private func create() {
        guard phase != .creating else { return }
        phase = .creating
        Task { @MainActor in
            do {
                // existing=true cai no mesmo caminho — confirmação idêntica
                // (o backend deduplica por sourceQuestionId).
                _ = try await container.api.createFlashcardFromQuestion(questionId: questionId)
                withAnimation(.easeInOut(duration: 0.2)) { phase = .done }
            } catch APIError.serverError(let code) where code == 422 {
                withAnimation(.easeInOut(duration: 0.2)) { phase = .discursive }
            } catch {
                NSLog("[QBank] createFlashcardFromQuestion(%d) error: %@", questionId, String(describing: error))
                withAnimation(.easeInOut(duration: 0.2)) { phase = .failed }
            }
        }
    }
}
