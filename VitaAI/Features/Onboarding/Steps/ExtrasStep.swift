import SwiftUI

/// Onboarding step DEPOIS do portal institucional: integrações pra vida fora
/// do app. Rafael 2026-04-28: Google Drive e Google Calendar saíram daqui —
/// vão pra outra fase de conectores extras (Settings/Conectores) depois.
/// Aqui ficam só WhatsApp (recomendado, end-to-end live) e Spotify (música
/// durante transcrição). Tudo opcional — botão "Pular, configuro depois" no
/// rodapé do shell.
struct ExtrasStep: View {
    let api: VitaAPI
    let onConnectWhatsApp: () -> Void
    let onConnectIntegration: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingSpeechBubble(
                text: "O Vita também consegue conectar com WhatsApp, Spotify e mais coisas pra te ajudar fora do app — recomendo o WhatsApp pra falar comigo direto pelo zap!"
            )

            VStack(spacing: 10) {
                extraCard(
                    letter: "W",
                    name: "WhatsApp",
                    subtitle: "Receba lembretes e fale comigo pelo zap",
                    color: Color(red: 0.15, green: 0.68, blue: 0.38),
                    badge: "RECOMENDADO",
                    action: onConnectWhatsApp
                )
                extraCard(
                    letter: "♫",
                    name: "Spotify",
                    subtitle: "Música de foco durante a transcrição",
                    color: Color(red: 0.11, green: 0.73, blue: 0.33),
                    badge: nil,
                    action: { onConnectIntegration("spotify") }
                )
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func extraCard(
        letter: String,
        name: String,
        subtitle: String,
        color: Color,
        badge: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Text(letter)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(VitaColors.accent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(VitaColors.accent.opacity(0.14)))
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.30))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
