import SwiftUI
import Sentry

// MARK: - FeedbackScreen
// Shell §5.2.10: shape canônico de Feedback. Backend não precisa endpoint novo —
// usa Sentry user feedback (SDK já ativo). Captura via SentrySDK.capture(message:)
// pra obter eventId, depois SentrySDK.capture(userFeedback:) com comentário, tipo,
// rating, email opcional, app version + device + OS injetados como tags.

struct FeedbackScreen: View {
    var onBack: (() -> Void)?

    @State private var rating: Int = 0
    @State private var feedbackType: FeedbackType = .suggestion
    @State private var feedbackText: String = ""
    @State private var contactEmail: String = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?

    enum FeedbackType: String, CaseIterable, Identifiable {
        case bug = "Bug"
        case suggestion = "Sugestão"
        case praise = "Elogio"
        case other = "Outro"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .bug: return "ant"
            case .suggestion: return "lightbulb"
            case .praise: return "heart"
            case .other: return "ellipsis.message"
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                headerBar
                    .padding(.top, 8)

                if didSubmit {
                    successView
                        .padding(.horizontal, 14)
                        .padding(.top, 60)
                } else {
                    formContent
                }

                Spacer().frame(height: 120)
            }
        }
        .background(Color.clear)
        .trackScreen("Feedback")
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

                Text("Feedback")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Form

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            intro
            ratingField
            typeField
            textField
            emailField

            if let errorMessage {
                errorBanner(errorMessage)
            }

            submitButton
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sua opinião nos faz melhor")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            Text("Bug, sugestão, elogio — todo feedback chega direto pra equipe e vira issue rastreável.")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                .lineSpacing(2)
        }
    }

    private var ratingField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Sua nota")
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: { rating = star }) {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                star <= rating
                                    ? VitaColors.accentLight.opacity(0.95)
                                    : VitaColors.textWarm.opacity(0.20)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) estrelas")
                }
                Spacer()
            }
        }
    }

    private var typeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Tipo")
            HStack(spacing: 8) {
                ForEach(FeedbackType.allCases) { type in
                    Button(action: { feedbackType = type }) {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 12, weight: .medium))
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(
                            feedbackType == type
                                ? VitaColors.accentLight.opacity(0.95)
                                : VitaColors.textPrimary.opacity(0.65)
                        )
                        .background(
                            feedbackType == type
                                ? VitaColors.accent.opacity(0.20)
                                : VitaColors.glassInnerLight.opacity(0.08)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                feedbackType == type
                                    ? VitaColors.accentHover.opacity(0.30)
                                    : VitaColors.accentHover.opacity(0.10),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var textField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Conta pra gente")
            ZStack(alignment: .topLeading) {
                if feedbackText.isEmpty {
                    Text("Descreva o que aconteceu, o que sentiu falta, ou o que achou legal...")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.30))
                        .padding(14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $feedbackText)
                    .font(.system(size: 13))
                    .foregroundStyle(VitaColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 120)
            }
            .background(VitaColors.glassInnerLight.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 1)
            )
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Email pra contato (opcional)")
            TextField("seu@email.com", text: $contactEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .padding(14)
                .background(VitaColors.glassInnerLight.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 1)
                )
                .foregroundStyle(VitaColors.textPrimary)
        }
    }

    private var submitButton: some View {
        Button(action: { Task { await submit() } }) {
            HStack(spacing: 8) {
                if isSubmitting { ProgressView().controlSize(.small).tint(VitaColors.accentLight) }
                Text(isSubmitting ? "Enviando..." : "Enviar feedback")
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
        .disabled(isSubmitting || !canSubmit)
        .opacity((isSubmitting || !canSubmit) ? 0.5 : 1.0)
    }

    private var canSubmit: Bool {
        !feedbackText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Success / Error

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(VitaColors.accentLight.opacity(0.85))
            Text("Recebido — vamos olhar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            Text("Obrigado por nos ajudar a melhorar. Se você deixou email, podemos voltar com uma resposta.")
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Button(action: { onBack?() }) {
                Text("Voltar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(VitaColors.accent.opacity(0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VitaColors.sectionLabel)
            .kerning(0.5)
    }

    // MARK: - Logic

    private func submit() async {
        guard canSubmit, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let trimmedText = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = Bundle.main.infoDictionary
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "—"
        let buildNumber = info?["CFBundleVersion"] as? String ?? "—"
        let device = UIDevice.current.model
        let os = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"

        // Sentry user feedback flow:
        // 1. Capture message com tags pra obter eventId.
        // 2. Anexar UserFeedback com comments + email + name no eventId.
        let messageEvent = SentrySDK.capture(message: "User feedback: \(feedbackType.rawValue)") { scope in
            scope.setTag(value: feedbackType.rawValue.lowercased(), key: "feedback.type")
            scope.setTag(value: "\(rating)", key: "feedback.rating")
            scope.setTag(value: appVersion, key: "feedback.appVersion")
            scope.setTag(value: buildNumber, key: "feedback.build")
            scope.setTag(value: device, key: "feedback.device")
            scope.setTag(value: os, key: "feedback.os")
            scope.setLevel(rating <= 2 ? .warning : .info)
        }

        let userFeedback = UserFeedback(eventId: messageEvent)
        userFeedback.comments = trimmedText
        let trimmedEmail = contactEmail.trimmingCharacters(in: .whitespaces)
        if !trimmedEmail.isEmpty { userFeedback.email = trimmedEmail }
        SentrySDK.capture(userFeedback: userFeedback)

        didSubmit = true
    }
}
