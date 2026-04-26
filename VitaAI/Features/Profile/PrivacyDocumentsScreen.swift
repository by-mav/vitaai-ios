import SwiftUI

// MARK: - PrivacyDocumentsScreen
// Shell §5.2.9: shape canônico da tela "Privacidade de documentos".
// Lista por categoria: O que coletamos × Onde processamos × Quanto guardamos.
// Toggle por categoria persiste via /api/user/data-preferences (não implementado
// ainda — mostra UI desabilitada até endpoint subir).

struct PrivacyDocumentsScreen: View {
    var onBack: (() -> Void)?
    var onExportData: (() -> Void)?
    var onDeleteAccount: (() -> Void)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerBar
                    .padding(.top, 8)

                introSection
                    .padding(.top, 16)
                    .padding(.horizontal, 14)

                sectionLabel("O que coletamos")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        ForEach(Self.collections.indices, id: \.self) { i in
                            collectionRow(Self.collections[i])
                            if i < Self.collections.count - 1 { divider }
                        }
                    }
                }
                .padding(.horizontal, 14)

                sectionLabel("Onde processamos")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        ForEach(Self.processing.indices, id: \.self) { i in
                            processingRow(Self.processing[i])
                            if i < Self.processing.count - 1 { divider }
                        }
                    }
                }
                .padding(.horizontal, 14)

                sectionLabel("Suas opções")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        actionRow(
                            icon: "square.and.arrow.up",
                            label: "Exportar meus dados",
                            desc: "Baixar tudo (LGPD)",
                            action: { onExportData?() }
                        )
                        divider
                        actionRow(
                            icon: "trash",
                            label: "Excluir conta permanentemente",
                            desc: "Apagar todos os dados — irreversível",
                            destructive: true,
                            action: { onDeleteAccount?() }
                        )
                    }
                }
                .padding(.horizontal, 14)

                Text("VitaAI cumpre LGPD (Lei 13.709/2018). DPO: privacy@vitaai.app")
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.30))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                Spacer().frame(height: 120)
            }
        }
        .background(Color.clear)
        .trackScreen("PrivacyDocuments")
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.75))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("backButton")

                Text("Privacidade de documentos")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Como protegemos o que você compartilha")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            Text("VitaAI lê PDFs do portal, áudio de aula e fotos de prova só pra te ajudar a estudar. Você pode exportar tudo a qualquer momento e deletar sua conta — apagamos em até 30 dias.")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                .lineSpacing(2)
        }
    }

    // MARK: - Rows

    fileprivate struct Collection {
        let icon: String
        let title: String
        let what: String
        let retention: String
    }

    fileprivate struct Processing {
        let icon: String
        let title: String
        let where_: String
        let isLocal: Bool
    }

    fileprivate static let collections: [Collection] = [
        .init(icon: "doc.fill", title: "Documentos do portal", what: "PDFs, slides, planos de ensino baixados de Canvas/Mannesoft/etc", retention: "Enquanto o portal estiver conectado"),
        .init(icon: "waveform", title: "Áudio de aula", what: "Gravações que você sobe pra transcrição", retention: "30 dias após a transcrição"),
        .init(icon: "photo.fill", title: "Fotos de prova", what: "Fotos de provas físicas que você sobe pra extração", retention: "90 dias após o upload"),
        .init(icon: "graduationcap.fill", title: "Dados acadêmicos", what: "Notas, frequência, horário, calendário, disciplinas", retention: "Enquanto a conta existir"),
        .init(icon: "message.fill", title: "Conversas com o coach IA", what: "Mensagens que você troca com o agente Vita", retention: "180 dias")
    ]

    fileprivate static let processing: [Processing] = [
        .init(icon: "cpu", title: "Transcrição (Whisper)", where_: "Servidor próprio (Brasil) — não vai pra nuvem terceirizada", isLocal: true),
        .init(icon: "brain", title: "Coach IA + extração de PDFs (vLLM)", where_: "Servidor próprio (Brasil) com Qwen3 — sem Anthropic/OpenAI", isLocal: true),
        .init(icon: "lock.fill", title: "Senhas dos portais", where_: "Cookies criptografados (AES-256), nunca a senha em texto", isLocal: true),
        .init(icon: "icloud.slash", title: "Backups", where_: "Cloudflare R2 (Brasil) com criptografia em repouso", isLocal: true)
    ]

    private func collectionRow(_ c: Collection) -> some View {
        HStack(spacing: 12) {
            iconBox(c.icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(c.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text(c.what)
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    .lineSpacing(1)
                Text("Retenção: \(c.retention)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.55))
                    .padding(.top, 2)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func processingRow(_ p: Processing) -> some View {
        HStack(spacing: 12) {
            iconBox(p.icon)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(p.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                    if p.isLocal {
                        Text("LOCAL")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(VitaColors.accent.opacity(0.20))
                            .clipShape(Capsule())
                    }
                }
                Text(p.where_)
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    .lineSpacing(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func actionRow(icon: String, label: String, desc: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconBox(icon, destructive: destructive)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(destructive ? VitaColors.dataRed.opacity(0.85) : Color.white.opacity(0.88))
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.20))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconBox(_ icon: String, destructive: Bool = false) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(destructive ? VitaColors.dataRed.opacity(0.10) : VitaColors.accentHover.opacity(0.14))
                .frame(width: 34, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke((destructive ? VitaColors.dataRed : VitaColors.accentHover).opacity(0.20), lineWidth: 1)
                )
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(destructive ? VitaColors.dataRed.opacity(0.85) : VitaColors.accentLight.opacity(0.85))
        }
    }

    private var divider: some View {
        Rectangle().fill(VitaColors.textWarm.opacity(0.04)).frame(height: 1)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}
