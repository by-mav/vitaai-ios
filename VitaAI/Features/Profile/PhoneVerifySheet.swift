import SwiftUI

// MARK: - PhoneVerifySheet
//
// Vincula telefone via WhatsApp. Backend já existe (POST /api/whatsapp/link →
// envia código 6 dígitos via Baileys ZAP API; POST /api/whatsapp/verify →
// confirma). Rafael 2026-04-25 — "envia a confirmação pelo WhatsApp".
//
// Fluxo (2 estados):
// 1. Phone — TextField com mask BR (99) 99999-9999. Tap "Enviar código" →
//    POST whatsapp/link, transita pra estado 2.
// 2. Code — 6 inputs OTP digit-by-digit. Auto-advance. Botão "Confirmar"
//    chama POST whatsapp/verify. Reenviar com cooldown 60s.

struct PhoneVerifySheet: View {
    /// Telefone atual do user (se já vinculado, vem em E.164 sem +). Nil = primeira vez.
    var initialPhone: String?
    var onVerified: () -> Void

    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    enum Step { case phone, code }
    @State private var step: Step = .phone

    @State private var phoneInput: String = ""
    @State private var phoneE164: String = ""    // 12-13 dígitos sem +
    @State private var code: String = ""
    @State private var resendCooldown: Int = 0
    @State private var resendTimer: Timer?

    @State private var isSending = false
    @State private var isVerifying = false
    @State private var errorMessage: String?

    var body: some View {
        VitaSheet(title: step == .phone ? "Vincular WhatsApp" : "Confirmar código", detents: [.medium, .large]) {
            VStack(alignment: .leading, spacing: 20) {
                if step == .phone {
                    phoneStep
                } else {
                    codeStep
                }

                if let errorMessage {
                    errorBanner(errorMessage)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .onAppear {
            phoneInput = initialPhone.map(formatBRDisplay) ?? ""
        }
        .onDisappear { resendTimer?.invalidate() }
    }

    // MARK: - Step 1: Phone

    private var phoneStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Por que telefone?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Text("VitaAI manda lembretes de prova, dúvidas do coach IA e código de recuperação pelo WhatsApp. Você pode desligar a qualquer momento.")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("WhatsApp")
                TextField("(00) 00000-0000", text: $phoneInput)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(VitaColors.glassInnerLight.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 1)
                    )
                    .foregroundStyle(VitaColors.textPrimary)
                    .onChange(of: phoneInput) { _, newValue in
                        let formatted = formatBRDisplay(rawDigitsFrom(newValue))
                        if formatted != newValue { phoneInput = formatted }
                        phoneE164 = "55" + rawDigitsFrom(newValue)
                    }
            }

            Button(action: { Task { await sendCode() } }) {
                HStack(spacing: 8) {
                    if isSending {
                        ProgressView().controlSize(.small).tint(VitaColors.accentLight)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(isSending ? "Enviando..." : "Enviar código pelo WhatsApp")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(VitaColors.accent.opacity(0.20))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(VitaColors.accentHover.opacity(0.30), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSending || !canSendCode)
            .opacity((isSending || !canSendCode) ? 0.5 : 1.0)
        }
    }

    private var canSendCode: Bool {
        // 12 ou 13 dígitos com 55 prefix (DDD 2 + 8|9 + 8 = 10|11 sem prefix)
        rawDigitsFrom(phoneInput).count >= 10
    }

    // MARK: - Step 2: Code

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Enviamos um código pra você")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                    Text(formatBRDisplay(rawDigitsFrom(phoneInput)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                }
                Text("Cole o código de 6 dígitos abaixo. O código expira em 10 minutos.")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Código")
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(VitaColors.glassInnerLight.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.accentHover.opacity(0.20), lineWidth: 1)
                    )
                    .foregroundStyle(VitaColors.textPrimary)
                    .onChange(of: code) { _, newValue in
                        let digits = newValue.filter(\.isNumber).prefix(6)
                        if String(digits) != newValue { code = String(digits) }
                    }
            }

            HStack(spacing: 12) {
                Button(action: { goBackToPhone() }) {
                    Text("Trocar número")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(VitaColors.glassInnerLight.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isVerifying)

                Button(action: { Task { await verify() } }) {
                    HStack(spacing: 8) {
                        if isVerifying { ProgressView().controlSize(.small).tint(VitaColors.accentLight) }
                        Text(isVerifying ? "Confirmando..." : "Confirmar")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(VitaColors.accent.opacity(0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isVerifying || code.count != 6)
                .opacity((isVerifying || code.count != 6) ? 0.5 : 1.0)
            }

            Button(action: { Task { await resendCode() } }) {
                Text(resendCooldown > 0 ? "Reenviar em \(resendCooldown)s" : "Reenviar código")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        resendCooldown > 0
                            ? VitaColors.textWarm.opacity(0.30)
                            : VitaColors.accentLight.opacity(0.80)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .disabled(resendCooldown > 0 || isSending)
        }
    }

    // MARK: - Common

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VitaColors.sectionLabel)
            .kerning(0.5)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VitaColors.dataRed.opacity(0.85))
            Text(msg)
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VitaColors.dataRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Logic

    private func sendCode() async {
        guard canSendCode, !isSending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        let raw = rawDigitsFrom(phoneInput)
        // Backend espera E.164 sem "+". 10 dígitos (sem 9 inicial) ou 11. Sempre prefixa 55.
        let payload = raw.hasPrefix("55") ? raw : "55" + raw
        phoneE164 = payload

        do {
            try await container.api.linkWhatsApp(phone: payload)
            HapticManager.shared.fire(.success)
            startResendCooldown()
            withAnimation(.easeInOut(duration: 0.25)) { step = .code }
        } catch {
            HapticManager.shared.fire(.warning)
            errorMessage = humanize(error: error, scope: "send")
        }
    }

    private func resendCode() async {
        guard resendCooldown == 0 else { return }
        await sendCode()
    }

    private func verify() async {
        guard code.count == 6, !isVerifying else { return }
        isVerifying = true
        errorMessage = nil
        defer { isVerifying = false }

        do {
            let resp = try await container.api.verifyWhatsApp(code: code)
            if resp.verified {
                HapticManager.shared.fire(.success)
                onVerified()
                dismiss()
            } else {
                HapticManager.shared.fire(.error)
                errorMessage = "Código inválido. Confere e tenta de novo."
            }
        } catch {
            HapticManager.shared.fire(.error)
            errorMessage = humanize(error: error, scope: "verify")
        }
    }

    private func goBackToPhone() {
        code = ""
        errorMessage = nil
        withAnimation(.easeInOut(duration: 0.25)) { step = .phone }
    }

    private func startResendCooldown() {
        resendCooldown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            Task { @MainActor in
                if resendCooldown > 0 {
                    resendCooldown -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }

    // MARK: - Format helpers

    /// "(51) 99999-9999" → "5199999999" (digits only, sem +).
    private func rawDigitsFrom(_ formatted: String) -> String {
        let digits = formatted.filter(\.isNumber)
        // Drop 55 prefix se já estiver (não duplica)
        if digits.hasPrefix("55") && digits.count > 11 {
            return String(digits.dropFirst(2))
        }
        return digits
    }

    /// "5199999999" ou "51999999999" → "(51) 99999-9999"
    private func formatBRDisplay(_ raw: String) -> String {
        let d = rawDigitsFrom(raw)
        guard !d.isEmpty else { return "" }
        var result = ""
        let chars = Array(d.prefix(11))
        for (i, c) in chars.enumerated() {
            switch i {
            case 0: result += "(\(c)"
            case 1: result += "\(c)) "
            case 6 where chars.count == 10: result += "-\(c)"
            case 7 where chars.count == 11: result += "-\(c)"
            default: result += "\(c)"
            }
        }
        return result
    }

    private func humanize(error: Error, scope: String) -> String {
        let msg = (error as NSError).localizedDescription.lowercased()
        if msg.contains("rate") || msg.contains("429") {
            return "Espera 1 minuto antes de pedir outro código."
        }
        if msg.contains("invalid phone") {
            return "Número inválido. Confere o DDD."
        }
        if msg.contains("send_failed") || msg.contains("502") {
            return "WhatsApp não respondeu agora. Tenta em alguns segundos."
        }
        if msg.contains("expired") || msg.contains("not found") {
            return "Código expirado ou inválido. Pede um novo."
        }
        return scope == "send"
            ? "Não conseguimos enviar agora. Tenta em alguns segundos."
            : "Não conseguimos confirmar. Tenta de novo."
    }
}
