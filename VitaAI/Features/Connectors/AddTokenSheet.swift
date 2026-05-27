// AddTokenSheet — substitui PortalConnectScreen webview legacy (graveyard 2026-05-07).
//
// Fluxo simples: user escolhe plataforma (v1: Canvas only), cola token + URL base,
// backend valida via Canvas API /users/self, persiste e dispara sync inicial.
//
// Spec: agent-brain/decisions/2026-05-07_vita-pivot-llm-extract-to-api-token-and-manual.md

import SwiftUI

struct AddTokenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer

    @State private var instanceUrl: String = ""
    @State private var token: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                VitaColors.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        instructions

                        VStack(alignment: .leading, spacing: 12) {
                            field(label: "Endereço Canvas", text: $instanceUrl, placeholder: "canvas.ulbra.br")
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)

                            field(label: "Personal Access Token", text: $token, placeholder: "Cole o token aqui")
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(16)
                        .background(VitaColors.surfaceCard, in: RoundedRectangle(cornerRadius: 14))

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                        }

                        if let successMessage {
                            Label(successMessage, systemImage: "checkmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 4)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Conectar Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Conectar").bold()
                        }
                    }
                    .disabled(isSubmitting || !canSubmit)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !instanceUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && token.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Conecta tua conta Canvas")
                .font(.title3.weight(.semibold))
            Text("Vita puxa tuas matérias, avaliações e materiais via API oficial Canvas — sem precisar guardar tua senha.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Como gerar o token:", systemImage: "info.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(VitaColors.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("1. Abre teu Canvas no navegador")
                Text("2. Clica em **Conta** → **Configurações**")
                Text("3. Rola até **Tokens de acesso aprovados**")
                Text("4. Clica em **+ Novo token de acesso**")
                Text("5. Copia o token e cola aqui")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(VitaColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func field(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(VitaColors.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func submit() {
        let trimmedUrl = instanceUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        errorMessage = nil
        successMessage = nil
        isSubmitting = true

        Task {
            defer { Task { @MainActor in isSubmitting = false } }
            do {
                let res = try await container.api.connectCanvas(
                    accessToken: trimmedToken,
                    instanceUrl: trimmedUrl
                )
                guard res.success, let connectionId = res.connectionId else {
                    await MainActor.run {
                        errorMessage = res.error ?? "Não foi possível validar o token. Tenta de novo."
                    }
                    return
                }

                // Sync inicial — bloqueia até concluir pra dar feedback visual
                let sync = try await container.api.syncCanvas(connectionId: connectionId)
                await MainActor.run {
                    successMessage = "Conectado! \(sync.courses) matérias, \(sync.assignments) avaliações sincronizadas."
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMessage = "Erro: \(error.localizedDescription)"
                }
            }
        }
    }
}
