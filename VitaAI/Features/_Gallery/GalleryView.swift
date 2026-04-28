import SwiftUI

// MARK: - GalleryView
//
// Tela de galeria de componentes duplicados para Rafael decidir qual mantém
// no SHELLAPP skill. Branch: gallery-experiment (NÃO entra em main).
// Issue: github.com/rafamav/one-hub/issues/22
//
// 5 grupos:
//  1. Buttons  — VitaButton / GlassAuthButton / SocialAuthButton / DisciplineCircleButton
//  2. Inputs   — VitaInput / GlassTextField / VitaVoiceInput / VitaInputPopout (skip)
//  3. Popouts  — VitaMenuPopout / VitaNotifPopout (skip) / VitaInputPopout (skip) / VitaNotificationSheet (model)
//  4. Mascots  — VitaFloatingMascot / VitaSpeakingMascot
//  5. Toasts   — VitaToast / VitaXpToast / VitaShimmer / VitaStreakBadge

// MARK: - GallerySection (Hashable para NavigationPath)

enum GallerySection: Int, Hashable, CaseIterable {
    case buttons = 1
    case inputs  = 2
    case popouts = 3
    case mascots = 4
    case toasts  = 5

    var title: String {
        switch self {
        case .buttons: return "Buttons"
        case .inputs:  return "Inputs"
        case .popouts: return "Popouts"
        case .mascots: return "Mascots"
        case .toasts:  return "Toasts & Badges"
        }
    }
    var subtitle: String {
        switch self {
        case .buttons: return "VitaButton · GlassAuthButton · SocialAuthButton · DisciplineCircleButton"
        case .inputs:  return "VitaInput · GlassTextField · VitaVoiceInput · [skip] VitaInputPopout"
        case .popouts: return "VitaMenuPopout · [skip×2] VitaNotifPopout · VitaInputPopout · [model] VitaNotificationSheet"
        case .mascots: return "VitaFloatingMascot · VitaSpeakingMascot"
        case .toasts:  return "VitaToast · VitaXpToast · VitaShimmer · VitaStreakBadge"
        }
    }
}

struct GalleryView: View {
    // Suporta deep-navigation via launch arg: `--section 2`
    // xcrun simctl launch booted com.bymav.vitaai --section 2
    @State private var path: [GallerySection] = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "--section"),
           idx + 1 < args.count,
           let n = Int(args[idx + 1]),
           let section = GallerySection(rawValue: n) {
            return [section]
        }
        return []
    }()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(GallerySection.allCases, id: \.self) { section in
                        NavigationLink(value: section) {
                            GalleryRowLabel(
                                number: "\(section.rawValue)",
                                title: section.title,
                                subtitle: section.subtitle
                            )
                        }
                    }
                } header: {
                    Text("Componentes Duplicados — Issue #22")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.accent.opacity(0.8))
                        .textCase(nil)
                }
            }
            .navigationTitle("Component Gallery")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: GallerySection.self) { section in
                switch section {
                case .buttons: ButtonsGallery()
                case .inputs:  InputsGallery()
                case .popouts: PopoutsGallery()
                case .mascots: MascotsGallery()
                case .toasts:  ToastsGallery()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - GalleryRowLabel

private struct GalleryRowLabel: View {
    let number: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(VitaColors.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(number)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(VitaColors.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - GalleryCard (helper wrapper)

private struct GalleryCard<Content: View>: View {
    let label: String
    var sublabel: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VitaColors.accent.opacity(0.9))
                    .textCase(.uppercase)
                    .tracking(1)
                if let sublabel {
                    Text(sublabel)
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VitaColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }
}

private struct SkipCard: View {
    let label: String
    let reason: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VitaColors.dataAmber)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Text("TODO ATLAS: \(reason)")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VitaColors.dataAmber.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(VitaColors.dataAmber.opacity(0.2), lineWidth: 1)
        )
    }
}

private var galleryBg: Color { VitaColors.surface }

// MARK: - 1. BUTTONS GALLERY

struct ButtonsGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                GalleryCard(
                    label: "VitaButton",
                    sublabel: "Sistema canônico — primary / secondary / ghost / danger"
                ) {
                    VStack(spacing: 10) {
                        VitaButton(text: "Continuar", action: {})
                        VitaButton(text: "Cancelar", action: {}, variant: .secondary)
                        VitaButton(text: "Saiba mais", action: {}, variant: .ghost)
                        VitaButton(text: "Excluir conta", action: {}, variant: .danger)
                        VitaButton(text: "Carregando…", action: {}, isLoading: true)
                    }
                }

                GalleryCard(
                    label: "GlassAuthButton",
                    sublabel: "Usado no onboarding auth (glass com ícone)"
                ) {
                    VStack(spacing: 10) {
                        GlassAuthButton(
                            label: "Entrar com conta Google",
                            icon: AnyView(
                                Image(systemName: "globe")
                                    .foregroundStyle(VitaColors.accent)
                            ),
                            isPrimary: false,
                            action: {}
                        )
                        GlassAuthButton(
                            label: "Verificar credenciais",
                            icon: AnyView(
                                Image(systemName: "checkmark.shield")
                                    .foregroundStyle(VitaColors.dataGreen)
                            ),
                            isPrimary: true,
                            action: {}
                        )
                    }
                }

                GalleryCard(
                    label: "SocialAuthButton",
                    sublabel: "HIG-compliant — Apple branco / Google dark glass + vitaSoftGlow"
                ) {
                    VStack(spacing: 10) {
                        SocialAuthButton(
                            provider: .apple,
                            label: "Continuar com Apple",
                            action: {}
                        )
                        SocialAuthButton(
                            provider: .google,
                            label: "Continuar com Google",
                            action: {}
                        )
                    }
                }

                GalleryCard(
                    label: "DisciplineCircleButton",
                    sublabel: "Fire badge circular com disciplina + label abaixo"
                ) {
                    HStack(spacing: 16) {
                        DisciplineCircleButton(name: "anatomia", size: 72, action: {})
                        DisciplineCircleButton(name: "cardiologia", size: 72, action: {})
                        DisciplineCircleButton(name: "bioquimica", size: 72, action: {})
                    }
                }

            }
            .padding(20)
        }
        .background(galleryBg)
        .navigationTitle("Buttons")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 2. INPUTS GALLERY

struct InputsGallery: View {
    @State private var vitaInputText = ""
    @State private var glassText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                GalleryCard(
                    label: "VitaInput",
                    sublabel: "Glass input canônico — label / placeholder / icon / error / helper"
                ) {
                    VStack(spacing: 12) {
                        VitaInput(
                            value: $vitaInputText,
                            label: "E-mail universitário",
                            placeholder: "seu@email.edu.br",
                            leadingSystemImage: "envelope"
                        )
                        VitaInput(
                            value: .constant("Senha errada"),
                            label: "Senha",
                            placeholder: "••••••••",
                            errorMessage: "Senha incorreta. Tente novamente.",
                            leadingSystemImage: "lock",
                            isSecure: true
                        )
                        VitaInput(
                            value: .constant(""),
                            label: "Campo desabilitado",
                            placeholder: "Indisponível no momento",
                            isEnabled: false
                        )
                    }
                }

                GalleryCard(
                    label: "GlassTextField",
                    sublabel: "Input simples glass — placeholder / binding / icon opcional"
                ) {
                    VStack(spacing: 10) {
                        GlassTextField(
                            placeholder: "Buscar disciplina…",
                            text: $glassText,
                            icon: "magnifyingglass"
                        )
                        GlassTextField(
                            placeholder: "Sem ícone",
                            text: .constant("Texto preenchido")
                        )
                    }
                }

                GalleryCard(
                    label: "VitaVoiceInput",
                    sublabel: "Mic button nativo com SFSpeechRecognizer + waveform Siri-style"
                ) {
                    HStack {
                        Spacer()
                        VitaVoiceInput(onTranscript: { _ in })
                        Spacer()
                    }
                }

                SkipCard(
                    label: "VitaInputPopout",
                    reason: "needs ChatViewModel + Namespace.ID — skip no gallery isolado"
                )

            }
            .padding(20)
        }
        .background(galleryBg)
        .navigationTitle("Inputs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 3. POPOUTS GALLERY

struct PopoutsGallery: View {
    @State private var showMenu = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                GalleryCard(
                    label: "VitaMenuPopout",
                    sublabel: "Glass popout 220px top-trailing — avatar + 7 ações + logout confirm"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Toque no botão para ver o popout ancorado no canto.")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textSecondary)

                        Button(action: { showMenu = true }) {
                            Label("Abrir VitaMenuPopout", systemImage: "person.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(VitaColors.accent)
                        }
                    }
                }

                GalleryCard(
                    label: "VitaNotificationSheet (MODEL)",
                    sublabel: "Foundation struct — NÃO é uma View. Modelo de dado de notificação."
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("struct VitaNotification: Identifiable, Decodable")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(VitaColors.textTertiary)
                        Text("Campos: id · type · title · description · time · read · source · subjectId · metadata")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textSecondary)
                            .lineLimit(3)
                        Text("⚠️ Não é componente visual — é o model que alimenta VitaNotifPopout.")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.dataAmber)
                    }
                }

                SkipCard(
                    label: "VitaNotifPopout",
                    reason: "needs @Environment(\\.appContainer) + PushManager.shared"
                )

                SkipCard(
                    label: "VitaInputPopout",
                    reason: "needs ChatViewModel + Namespace.ID (chat attach panel)"
                )

            }
            .padding(20)
        }
        .background(galleryBg)
        .navigationTitle("Popouts")
        .navigationBarTitleDisplayMode(.inline)
        // VitaMenuPopout como overlay full-screen
        .overlay {
            if showMenu {
                VitaMenuPopout(
                    userName: "Rafael Loureiro",
                    userImageURL: nil,
                    onProfile:         { showMenu = false },
                    onNotifications:   { showMenu = false },
                    onAgenda:          { showMenu = false },
                    onConfiguracoes:   { showMenu = false },
                    onAppearance:      { showMenu = false },
                    onConnections:     { showMenu = false },
                    onPaywall:         { showMenu = false },
                    onLogout:          { showMenu = false },
                    onDismiss:         { showMenu = false }
                )
            }
        }
    }
}

// MARK: - 4. MASCOTS GALLERY

struct MascotsGallery: View {
    @State private var mascotActive = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                GalleryCard(
                    label: "VitaSpeakingMascot",
                    sublabel: "Mascote contextual estilo Duolingo — balão de fala + persona + prop"
                ) {
                    VStack(spacing: 24) {
                        HStack(spacing: 24) {
                            VStack(spacing: 6) {
                                VitaSpeakingMascot(
                                    persona: .idle,
                                    speech: "Olá, {name}!",
                                    userName: "Rafael"
                                )
                                Text(".idle")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                            VStack(spacing: 6) {
                                VitaSpeakingMascot(
                                    persona: .guiding,
                                    speech: "Vamos estudar!"
                                )
                                Text(".guiding")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                            VStack(spacing: 6) {
                                VitaSpeakingMascot(
                                    persona: .cheering,
                                    speech: "Incrível, {name}!",
                                    userName: "Rafael"
                                )
                                Text(".cheering")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                        }

                        HStack(spacing: 24) {
                            VStack(spacing: 6) {
                                VitaSpeakingMascot(persona: .studying())
                                Text(".studying")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                            VStack(spacing: 6) {
                                VitaSpeakingMascot(persona: .thinking)
                                Text(".thinking")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                            VStack(spacing: 6) {
                                VitaSpeakingMascot(persona: .celebrating())
                                Text(".celebrating")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                GalleryCard(
                    label: "VitaFloatingMascot",
                    sublabel: "Draggável, ancorável nas bordas, persiste posição via UserDefaults"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mascote flutuante aparece no canto inferior direito da tela. Draggável. Long-press minimiza pra borda.")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textSecondary)

                        Toggle("Ativar VitaFloatingMascot (pulse ativo)", isOn: $mascotActive)
                            .toggleStyle(SwitchToggleStyle(tint: VitaColors.accent))
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textPrimary)
                    }
                }

            }
            .padding(20)
        }
        .background(galleryBg)
        .navigationTitle("Mascots")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            VitaFloatingMascot(
                positionKey: "gallery_mascot",
                bottomInset: 80,
                isActive: mascotActive,
                onTap: { mascotActive.toggle() }
            )
        }
    }
}

// MARK: - 5. TOASTS & BADGES GALLERY

struct ToastsGallery: View {
    @State private var toastState = VitaToastState()
    @State private var xpToastState = VitaXpToastState()
    @State private var streak = 7

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                GalleryCard(
                    label: "VitaToast",
                    sublabel: "Sistema de notificações contextuais — success / error / warning / info"
                ) {
                    VStack(spacing: 8) {
                        Text("Toque para disparar cada tipo de toast:")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textTertiary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            toastButton("Sucesso", type: .success, icon: "checkmark.circle.fill")
                            toastButton("Erro", type: .error, icon: "xmark.circle.fill")
                            toastButton("Aviso", type: .warning, icon: "exclamationmark.triangle.fill")
                            toastButton("Info", type: .info, icon: "info.circle.fill")
                        }
                    }
                }

                GalleryCard(
                    label: "VitaXpToast",
                    sublabel: "Gamificação — pill teal '+25 XP' com sparkles"
                ) {
                    VStack(spacing: 8) {
                        Text("Toque para ver a pill de XP:")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textTertiary)

                        HStack(spacing: 8) {
                            xpButton("+10 XP · Flashcard", amount: 10, source: .flashcardReview)
                            xpButton("+50 XP · Questão", amount: 50, source: .questionAnswered)
                        }
                    }
                }

                GalleryCard(
                    label: "VitaShimmer",
                    sublabel: "Skeleton loading — ShimmerBox + ShimmerText + modificador .shimmer()"
                ) {
                    VStack(spacing: 10) {
                        ShimmerBox(height: 48, cornerRadius: 14)
                        ShimmerBox(height: 24, cornerRadius: 8)
                        HStack(spacing: 10) {
                            ShimmerBox(height: 80, cornerRadius: 12)
                            ShimmerBox(height: 80, cornerRadius: 12)
                            ShimmerBox(height: 80, cornerRadius: 12)
                        }
                    }
                }

                GalleryCard(
                    label: "VitaStreakBadge",
                    sublabel: "Streak badge com chama animada — ativo (amber pulse) / inativo (cinza)"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                VitaStreakBadge(streak: streak, size: .md)
                                Text(".md · streak=\(streak)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                            VStack(spacing: 4) {
                                VitaStreakBadge(streak: streak, size: .sm)
                                Text(".sm")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                            VStack(spacing: 4) {
                                VitaStreakBadge(streak: 0, size: .md)
                                Text("inativo")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                        }

                        Stepper("Streak: \(streak)", value: $streak, in: 0...365)
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textPrimary)
                    }
                }

            }
            .padding(20)
        }
        .background(galleryBg)
        .navigationTitle("Toasts & Badges")
        .navigationBarTitleDisplayMode(.inline)
        .vitaToastHost(toastState)
        .vitaXpToastHost(xpToastState)
    }

    @ViewBuilder
    private func toastButton(_ label: String, type: VitaToastType, icon: String) -> some View {
        Button {
            toastState.show("\(label): \(type == .error ? "Falha ao salvar." : "Operação bem-sucedida.")", type: type)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(type.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(type.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(type.color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func xpButton(_ label: String, amount: Int, source: XpSource) -> some View {
        Button {
            xpToastState.show(XpEvent(amount: amount, source: source))
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(VitaColors.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(VitaColors.accent.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
