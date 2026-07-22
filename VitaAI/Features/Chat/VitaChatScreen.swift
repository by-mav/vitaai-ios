import SwiftUI
import PhotosUI
import Sentry

// MARK: - VitaChatScreen — Overlay between top bar and tab bar
//
// PORT 1:1 do PixioChatScreen (pixio-ios/Pixio/Features/Chat/PixioChatScreen.swift).
// Mesma estrutura/forma/posição: header (≡ histórico + nova + fechar), bolhas com
// cometa "Pensando", composer com glow cometa girante, drawer de conversas.
// Cores resolvem nos tokens DOURADOS do Vita via PixioCompat. A API usada é a do
// ChatViewModel do Vita (não a do Pixio). SOT: decisions/2026-06-16_vita-pixio-ui-port.md

struct VitaChatScreen: View {
    @Environment(\.appContainer) private var container
    var onClose: () -> Void
    /// Pre-attached image (JPEG Data) shown as soon as the chat opens.
    /// Used by the PDF viewer "Pergunte ao Vita" scanner to pipe a page screenshot in.
    var initialImageData: Data? = nil
    /// Pre-filled prompt sent automatically when the chat opens.
    /// Used by the Atlas 3D "Perguntar pra VITA sobre …" button.
    var initialPrompt: String? = nil
    @State private var viewModel: ChatViewModel?
    @State private var showVoiceMode: Bool = false
    @State private var showPlusPopout: Bool = false
    /// Arraste-pra-fechar do drawer de conversas (canon Pixio 2026-06-14).
    @State private var historyDragOffset: CGFloat = 0
    @Namespace private var plusNS
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            // Aurora graphite EDGE-TO-EDGE (tem .ignoresSafeArea interno). Como
            // IRMAO no ZStack (NAO .background): so o fundo ignora a safe area, o
            // conteudo respeita. Senao o conteudo vazava pra fora e o header sumia
            // atras do notch + o composer caia fora da base (bug "so o mascote").
            PixioAuroraBackground()
            Group {
                if let viewModel {
                    chatContent(viewModel: viewModel)
                } else {
                    DashboardSkeleton()
                        .tint(VitaColors.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.30), radius: 14, x: 0, y: 6)
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(
                    chatClient: container.chatClient,
                    api: container.api
                )
            }
            viewModel?.newConversation()
            // Pre-load history em background ao abrir VitaChat — usuário não
            // espera 2-3s quando clica no menu de histórico depois.
            if let vm = viewModel {
                Task { await vm.loadHistory() }
            }
            if let initialImageData {
                viewModel?.setImageAttachment(data: initialImageData)
                // Focus the input so Rafael can type a question immediately over the attached image.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isInputFocused = true
                }
            }
            if let prompt = initialPrompt, !prompt.isEmpty, let vm = viewModel {
                // Auto-send the pre-filled prompt — student tapped "Perguntar
                // pra VITA" expecting an answer, not an empty input.
                vm.inputText = prompt
                Task { await vm.send() }
            }
            // Chat is interactive immediately — no async fetch needed before first render.
            SentrySDK.reportFullyDisplayed()
        }
        .fullScreenCover(isPresented: $showVoiceMode) {
            VoiceModeScreen(
                viewModel: VoiceModeViewModel(chatClient: container.chatClient),
                onDismiss: { showVoiceMode = false }
            )
        }
        .trackScreen("VitaChat")
    }

    @ViewBuilder
    private func chatContent(viewModel: ChatViewModel) -> some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                // Header — history toggle + new conversation + close
                ChatHeader(
                    onHistory: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.showHistory.toggle()
                            if viewModel.showHistory {
                                Task { await viewModel.loadHistory() }
                            }
                        }
                    },
                    onNewConversation: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.newConversation()
                        }
                    },
                    onClose: onClose,
                    // Show "Pergunte ao Vita" title when opened from PDF viewer scanner
                    // (initialImageData attached) — gives the user clear context that this
                    // is a sub-task with an exit, not the main Vita Coach.
                    title: initialImageData != nil ? "Pergunte ao Vita" : nil
                )

                // Messages or empty state
                if viewModel.messages.isEmpty {
                    EmptyState(viewModel: viewModel, isInputFocused: $isInputFocused)
                } else {
                    MessagesList(viewModel: viewModel)
                }

                // Input bar
                ChatInput(
                    viewModel: viewModel,
                    isInputFocused: $isInputFocused,
                    namespace: plusNS,
                    isPlusPopoutOpen: showPlusPopout,
                    onPlusTap: {
                        withAnimation(VitaModalTokens.openSpring) { showPlusPopout = true }
                    }
                )
            }

            // Scrim atrás do drawer — tocar fora (no chat) FECHA o menu de
            // conversas (canon Pixio 2026-06-14).
            if viewModel.showHistory {
                PixioColor.scrim
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) { viewModel.showHistory = false }
                    }
                    .transition(.opacity)
                    .zIndex(50)
            }

            // History sidebar overlay — arrastável pra ESQUERDA pra fechar
            // (canon Pixio 2026-06-14).
            if viewModel.showHistory {
                HistoryPanel(viewModel: viewModel)
                    .offset(x: historyDragOffset)
                    .transition(.move(edge: .leading))
                    .zIndex(60)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 15)
                            .onChanged { v in
                                if v.translation.width < 0,
                                   abs(v.translation.width) > abs(v.translation.height) {
                                    historyDragOffset = v.translation.width
                                }
                            }
                            .onEnded { v in
                                let horizontal = abs(v.translation.width) > abs(v.translation.height)
                                if horizontal,
                                   v.translation.width < -80 || v.predictedEndTranslation.width < -250 {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        viewModel.showHistory = false
                                    }
                                }
                                withAnimation(.easeInOut(duration: 0.2)) { historyDragOffset = 0 }
                            }
                    )
            }

            // Backdrop blur para VitaInputPopout — idêntico ao backdrop do hamburguer.
            if showPlusPopout {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(VitaModalTokens.openSpring) { showPlusPopout = false }
                    }
                    .zIndex(199)

                VitaInputPopout(
                    viewModel: viewModel,
                    namespace: plusNS,
                    onDismiss: {
                        withAnimation(VitaModalTokens.openSpring) { showPlusPopout = false }
                    }
                )
                .transition(.opacity)
                .zIndex(200)
            }
        }
    }
}

// MARK: - Header

private struct ChatHeader: View {
    var onHistory: () -> Void
    var onNewConversation: () -> Void = {}
    let onClose: () -> Void
    var title: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            // Hamburger — opens conversation history
            Button(action: onHistory) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Histórico")

            Spacer()

            // Optional contextual title (e.g. "Pergunte ao Vita" when opened from PDF viewer)
            if let title {
                Text(title)
                    .font(VitaTypography.titleSmall)
                    .foregroundColor(VitaColors.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            // Nova conversa — tile elevado premium (canon Pixio: pixioRaised in Circle).
            Button(action: onNewConversation) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VitaColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .pixioRaised(in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nova conversa")

            // Fechar — dismiss canon (chevron.down): full-screen volta pra baixo.
            PixioSheetDismissButton(action: onClose)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Empty State

private struct EmptyState: View {
    let viewModel: ChatViewModel
    var isInputFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // VITA mascot VESTIDO com a skin equipada do usuário (Fase 1).
                // Rafael: nunca a estrela SF "sparkles" aqui.
                VitaMascotEquipped(state: .awake, size: 88)
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)

                Text("Como posso te ajudar?")
                    .font(.system(size: 14))
                    .foregroundColor(VitaColors.textSecondary)

                // Quick action chips — glassmorphism premium (canon Pixio).
                HStack(spacing: 8) {
                    ForEach(Self.suggestions, id: \.self) { text in
                        Button {
                            viewModel.inputText = text
                            isInputFocused.wrappedValue = true
                            Task { await viewModel.send() }
                        } label: {
                            Text(text)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(VitaColors.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .pixioGlass(.regular, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(VitaColors.glassBorder, lineWidth: 0.6)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private static let suggestions = [
        "O que estudar hoje?",
        "Análise meu progresso",
    ]
}

// MARK: - Messages List

private struct MessagesList: View {
    let viewModel: ChatViewModel
    /// Namespace pro teleporte do avatar do mascote entre mensagens
    /// (matchedGeometryEffect) — canon Pixio 2026-05-13.
    @Namespace private var mascotNS
    @State private var userScrolledUp: Bool = false

    /// ID da última mensagem do bot. Avatar do mascote só aparece nessa.
    private var lastAssistantMessageId: String? {
        viewModel.messages.last(where: { $0.role != "user" })?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        self.messageRow(for: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                userScrolledUp = false
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.content) { _ in
                guard !userScrolledUp else { return }
                scrollToBottom(proxy: proxy)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8).onChanged { value in
                    if value.translation.height > 30 && viewModel.isStreaming {
                        userScrolledUp = true
                    }
                }
            )
        }
    }

    @ViewBuilder
    private func messageRow(for message: ChatMessage) -> some View {
        let isLast = message.id == viewModel.messages.last?.id
        let isLastBotMsg = message.id == lastAssistantMessageId
        let onRetry: (() -> Void)? = message.isError ? {
            Task { await viewModel.retryLastMessage() }
        } : nil
        MessageRow(
            message: message,
            isStreaming: viewModel.isStreaming && isLast,
            activityState: viewModel.activityState,
            isLastBotMessage: isLastBotMsg,
            avatarNamespace: mascotNS,
            onRetry: onRetry,
            onFeedback: { value in
                Task { await viewModel.sendFeedback(messageId: message.id, value: value) }
            }
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = viewModel.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: ChatMessage
    let isStreaming: Bool
    let activityState: AIActivityState
    /// True somente na ÚLTIMA mensagem do bot — só ela mostra o avatar do
    /// mascote (matchedGeometryEffect "teleporta" quando a próxima chega).
    let isLastBotMessage: Bool
    let avatarNamespace: Namespace.ID
    var onRetry: (() -> Void)?
    var onFeedback: ((Int) -> Void)?
    @State private var cursorVisible: Bool = true

    private var isUser: Bool { message.role == "user" }

    /// Estado "pensando" = resposta ainda vazia enquanto o stream começa.
    /// Renderiza o cometa compacto (PixioThinkingIndicator) no lugar da bolha.
    private var isThinking: Bool { message.content.isEmpty && isStreaming }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 52)
                userBubble
            } else {
                if isLastBotMessage {
                    assistantAvatar
                        .matchedGeometryEffect(id: "vita-mascot", in: avatarNamespace)
                        .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .bottomLeading)))
                } else {
                    Color.clear
                        .frame(width: 26, height: 26)
                        .alignmentGuide(.bottom) { d in d[.bottom] }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if isThinking {
                        AIActivityIndicator(state: activityState)
                    } else {
                        assistantBubble
                        if message.isError, let onRetry {
                            Button(action: onRetry) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("Tentar novamente")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(VitaColors.dataRed)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(VitaColors.dataRed.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        // Action buttons (👍/👎/copy/share/time) — SEMPRE visíveis
                        // abaixo da resposta do bot (canon ChatGPT/Claude 2026).
                        if !isStreaming && !message.content.isEmpty && !message.isError {
                            MessageActions(message: message, onFeedback: onFeedback)
                        }
                    }
                }
                Spacer(minLength: 52)
            }
        }
    }

    private var userBubble: some View {
        let themeColor = PixioCoState.shared.activeThemeColor.color
        let bubbleShape = RoundedRectangle(cornerRadius: PixioRadius.hero, style: .continuous)
        return VStack(alignment: .trailing, spacing: 8) {
            if let image = message.uiImage {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: 200, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: PixioRadius.iconBadge))
            }
            if message.content != "[Imagem]" || !message.hasImage {
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundColor(PixioColor.textLight)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .pixioGlass(.clearTinted(themeColor.opacity(0.35)), in: bubbleShape)
        .overlay(
            bubbleShape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.45), .white.opacity(0.08), .clear],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: 0.6
            )
        )
        .shadow(color: themeColor.opacity(0.18), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    private var assistantAvatar: some View {
        Image("vita-btn-active")
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
            .clipShape(Circle())
            .alignmentGuide(.bottom) { d in d[.bottom] }
    }

    private var assistantBubble: some View {
        Group {
            if isStreaming {
                (Text(message.content)
                    .font(.system(size: 13))
                    .foregroundColor(VitaColors.textPrimary)
                + Text(cursorVisible ? " |" : "  ")
                    .font(.system(size: 13))
                    .foregroundColor(VitaColors.textSecondary))
            } else {
                VitaMarkdown(content: message.content)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: PixioRadius.hero, style: .continuous).fill(.ultraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: PixioRadius.hero, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PixioRadius.hero, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 2)
        .onAppear {
            if isStreaming { startCursorBlink() }
        }
        .onChange(of: isStreaming) { streaming in
            if !streaming { cursorVisible = false }
        }
    }

    private func startCursorBlink() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            cursorVisible = false
        }
    }
}

// MARK: - History Panel
//
// PORT do HistoryPanel do Pixio. Nav items no topo (Nova / Buscar / Projetos)
// + lista de conversas agrupada por data. Vita NÃO tem backend de projetos
// nem busca server-side: "Projetos" abre placeholder, "Buscar" filtra local.

private struct HistoryPanel: View {
    let viewModel: ChatViewModel

    @State private var showSearch: Bool = false
    @State private var searchQuery: String = ""
    /// Vita ainda não tem backend de Projetos — sheet placeholder. // TODO projetos backend
    @State private var showProjectsPlaceholder: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Spacer().frame(height: 8)

                // Nav items (ChatGPT pattern) — alinhados à esquerda
                VStack(spacing: 2) {
                    ChatSidebarNavItem(
                        icon: "square.and.pencil",
                        title: "Nova conversa",
                        action: { viewModel.newConversation() }
                    )
                    ChatSidebarNavItem(
                        icon: "magnifyingglass",
                        title: "Buscar conversas",
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSearch.toggle()
                                if !showSearch { searchQuery = "" }
                            }
                        }
                    )
                    // TODO projetos backend — Vita ainda não tem modelo/endpoint
                    // de projetos. UI portada do Pixio, abre placeholder.
                    ChatSidebarNavItem(
                        icon: "folder",
                        title: "Projetos",
                        action: { showProjectsPlaceholder = true }
                    )
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

                // Search input (slide-in)
                if showSearch {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(VitaColors.textSecondary)
                        TextField("Buscar título…", text: $searchQuery)
                            .font(.system(size: 13))
                            .foregroundColor(VitaColors.textPrimary)
                            .textFieldStyle(.plain)
                            .tint(VitaColors.accent)
                        if !searchQuery.isEmpty {
                            Button { searchQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(VitaColors.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .pixioFieldSurface()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Divider()
                    .overlay(VitaColors.glassBorder)

                if filteredConversations.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: viewModel.conversations.isEmpty
                              ? "bubble.left.and.bubble.right"
                              : "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(VitaColors.textTertiary)
                        Text(viewModel.conversations.isEmpty
                             ? "Nenhuma conversa ainda"
                             : "Nada encontrado")
                            .font(.system(size: 12))
                            .foregroundColor(VitaColors.textTertiary)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 1) {
                            ForEach(groupedConversations, id: \.key) { group in
                                Text(group.key)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(VitaColors.textTertiary)
                                    .textCase(.uppercase)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                                    .padding(.bottom, 4)

                                ForEach(group.items) { conv in
                                    HistoryRow(
                                        conversation: conv,
                                        isActive: conv.id == viewModel.currentConversationId
                                    ) {
                                        Task { await viewModel.loadConversation(conv) }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
            // Close button overlay top-right (não consome altura no VStack)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.showHistory = false
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(VitaColors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(VitaColors.textWarm.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 12)
        }
        .frame(width: 296)
        .frame(maxHeight: .infinity)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(width: 1)
        }
        .sheet(isPresented: $showProjectsPlaceholder) {
            ProjectsPlaceholderSheet()
        }
    }

    private struct DateGroup: Identifiable {
        let key: String
        let items: [ConversationEntry]
        var id: String { key }
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = frac.date(from: string) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    /// Conversas após filtro de busca (título OU preview, case-insensitive).
    private var filteredConversations: [ConversationEntry] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.conversations }
        return viewModel.conversations.filter { conv in
            let title = conv.title ?? ""
            let preview = conv.messagePreview ?? ""
            return title.localizedCaseInsensitiveContains(trimmed)
                || preview.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var groupedConversations: [DateGroup] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [ConversationEntry]] = [:]
        var order: [String] = []

        for conv in filteredConversations {
            let label: String
            if let date = parseDate(conv.updatedAt) {
                if calendar.isDateInToday(date) {
                    label = "Hoje"
                } else if calendar.isDateInYesterday(date) {
                    label = "Ontem"
                } else if calendar.dateComponents([.day], from: date, to: now).day ?? 8 < 7 {
                    label = "Esta semana"
                } else {
                    let df = DateFormatter()
                    df.dateFormat = "MMMM yyyy"
                    df.locale = Locale(identifier: "pt-BR")
                    label = df.string(from: date).capitalized
                }
            } else {
                label = "Sem data"
            }

            if groups[label] == nil { order.append(label) }
            groups[label, default: []].append(conv)
        }

        return order.map { DateGroup(key: $0, items: groups[$0] ?? []) }
    }
}

// MARK: - Sidebar nav item (PORT do ChatSidebarNavItem do Pixio)

private struct ChatSidebarNavItem: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(VitaColors.textSecondary)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VitaColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Projects placeholder (Vita não tem backend de projetos ainda)

private struct ProjectsPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundColor(VitaColors.textTertiary)
            Text("Projetos")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VitaColors.textPrimary)
            Text("Em breve você vai poder organizar suas conversas em projetos.")
                .font(.system(size: 13))
                .foregroundColor(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button("Fechar") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(VitaColors.accent)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PixioAuroraBackground())
        .presentationDetents([.medium])
    }
}

private struct HistoryRow: View {
    let conversation: ConversationEntry
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.title ?? "Nova conversa")
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? VitaColors.accent : VitaColors.textPrimary)
                    .lineLimit(1)

                if let preview = conversation.messagePreview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 11))
                        .foregroundColor(VitaColors.textTertiary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isActive ? VitaColors.accent.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Actions (copy, share, time)

private struct MessageActions: View {
    let message: ChatMessage
    var onFeedback: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            // Response time
            if let duration = message.responseDuration {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(formatDuration(duration))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(VitaColors.textTertiary)
            }

            Spacer()

            // Thumbs up
            Button {
                let newValue = message.feedback == 1 ? 0 : 1
                if newValue != 0 { onFeedback?(newValue) }
            } label: {
                Image(systemName: message.feedback == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 11))
                    .foregroundColor(message.feedback == 1 ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Gostei")

            // Thumbs down
            Button {
                let newValue = message.feedback == -1 ? 0 : -1
                if newValue != 0 { onFeedback?(newValue) }
            } label: {
                Image(systemName: message.feedback == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 11))
                    .foregroundColor(message.feedback == -1 ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Não gostei")

            // Copy
            Button {
                UIPasteboard.general.string = message.content
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(VitaColors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copiar")

            // Share — ShareLink nativo SwiftUI (resolve o topmost controller sozinho,
            // diferente de UIActivityViewController.present que não mostra nada com
            // o chat overlay aberto). Canon Pixio 2026-05-13.
            ShareLink(item: message.content) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                    .foregroundColor(VitaColors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Compartilhar")
        }
        .padding(.horizontal, 4)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1 { return "<1s" }
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m \(s % 60)s"
    }
}

// MARK: - BYMAV AI Activity Protocol v1

private struct AIActivityIndicator: View {
    let state: AIActivityState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var themeColor: Color { PixioCoState.shared.activeThemeColor.color }

    var body: some View {
        let shape = Capsule(style: .continuous)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, date: timeline.date)
            }
        }
        .frame(width: 20, height: 20)
        .frame(width: 48, height: 38)
        .pixioGlass(.clearTinted(themeColor.opacity(0.18)), in: shape)
        .overlay(shape.strokeBorder(PixioColor.glassBorder, lineWidth: 1))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private enum Mode { case orbits, globe, rubik, wave, ribbon, morph }
    private struct OrbPoint { let x: Double; let y: Double; let z: Double }

    private var mode: Mode {
        switch state {
        case .searching: return .globe
        case .solving, .error: return .rubik
        case .listening, .speaking: return .wave
        case .composing: return .ribbon
        case .shaping: return .morph
        case .idle, .working, .cancelled: return .orbits
        }
    }

    private var speed: Double {
        switch mode {
        case .orbits: return 3.9
        case .globe: return 2.665
        case .rubik: return 1.95
        case .wave: return 3.998
        case .ribbon: return 3.12
        case .morph: return 2.08
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .searching: return "Vita está buscando"
        case .solving: return "Vita está analisando"
        case .composing: return "Vita está compondo"
        case .listening: return "Vita está ouvindo"
        case .speaking: return "Vita está falando"
        case .shaping: return "Vita está criando"
        case .error: return "Vita encontrou um erro"
        case .cancelled: return "Resposta cancelada"
        case .idle, .working: return "Vita está pensando"
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, date: Date) {
        let phase = reduceMotion ? 0.22 : date.timeIntervalSinceReferenceDate * speed
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let extent = min(size.width, size.height) * 0.39
        let points = (0..<12).map { point(index: $0, count: 12, phase: phase) }.sorted { $0.z < $1.z }
        for point in points {
            let depth = (point.z + 1) / 2
            let radius = max(CGFloat(0.75), size.width * CGFloat(0.018 + depth * 0.018))
            let rect = CGRect(
                x: center.x + CGFloat(point.x) * extent - radius,
                y: center.y + CGFloat(point.y) * extent - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(themeColor.opacity(0.34 + depth * 0.66)))
        }
    }

    private func point(index: Int, count: Int, phase: Double) -> OrbPoint {
        let t = Double(index) / Double(count)
        let turn = Double.pi * 2
        switch mode {
        case .globe:
            let y = 1 - 2 * ((Double(index) + 0.5) / Double(count))
            let radius = sqrt(max(0, 1 - y * y))
            let angle = Double(index) * 2.399963 + phase
            return .init(x: cos(angle) * radius, y: y, z: sin(angle) * radius)
        case .rubik:
            let side = 3
            let x = Double(index % side) - 1
            let y = Double((index / side) % side) - 1
            let z = Double(index / (side * side)) - 0.5
            let angle = phase * 0.55 + Double(index / side) * 0.08
            return .init(x: x * cos(angle) - z * sin(angle), y: y, z: x * sin(angle) + z * cos(angle))
        case .wave:
            return .init(x: t * 2 - 1, y: sin(t * turn * 2.2 + phase) * 0.48, z: cos(t * turn + phase) * 0.45)
        case .ribbon:
            let lane = index % 3
            let laneT = Double(index / 3) / 3
            return .init(x: laneT * 2 - 1, y: sin(laneT * turn * 1.35 + phase) * 0.42 + Double(lane - 1) * 0.22, z: cos(laneT * turn + phase + Double(lane)) * 0.5)
        case .morph:
            let angle = t * turn + phase * 0.35
            let radius = 0.62 + sin(t * turn * 3 + phase) * 0.22
            return .init(x: cos(angle) * radius, y: sin(angle) * radius, z: sin(angle * 2 + phase) * 0.5)
        case .orbits:
            let orbit = index % 3
            let angle = t * turn * 2 + phase * (orbit == 1 ? -0.8 : 1)
            let radius = 0.45 + Double(orbit) * 0.2
            return .init(x: cos(angle) * radius, y: sin(angle) * radius * (0.3 + Double(orbit) * 0.22), z: sin(angle + Double(orbit) * 1.7))
        }
    }
}

// MARK: - Comet glow (borda "cometa" girante reutilizável) — PORT do Pixio
//
// Mesmo efeito do PixioThinkingIndicator (comet AngularGradient orbitando a
// borda + halo borrado), extraído pra reusar em volta do composer "Pergunte
// ao Vita". Sem o "breathe" — só a luz que circula.
private struct PixioCometGlow<S: InsettableShape>: ViewModifier {
    let shape: S
    let themeColor: Color
    var lineWidth: CGFloat = 1.6
    /// Segundos por volta — mais alto = mais devagar/calmo (premium).
    var duration: Double = 1.9
    /// 0…1 — brilho do cometa. Mais baixo = mais sutil, menos distrai.
    var intensity: Double = 1.0
    @State private var sweep: Double = 0

    private var cometGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .clear,                               location: 0.00),
                .init(color: .clear,                               location: 0.58),
                .init(color: themeColor.opacity(0.40 * intensity), location: 0.76),
                .init(color: themeColor.opacity(0.85 * intensity), location: 0.88),
                .init(color: themeColor.opacity(0.40 * intensity), location: 0.96),
                .init(color: .clear,                               location: 1.00),
            ]),
            center: .center,
            angle: .degrees(sweep)
        )
    }

    func body(content: Content) -> some View {
        content
            .overlay(shape.strokeBorder(cometGradient, lineWidth: lineWidth))
            .overlay(
                shape.strokeBorder(cometGradient, lineWidth: lineWidth + 1.4)
                    .blur(radius: 6)
                    .opacity(0.5 * intensity)
            )
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    sweep = 360
                }
            }
    }
}

private extension View {
    func pixioCometGlow<S: InsettableShape>(_ shape: S, themeColor: Color,
                                            lineWidth: CGFloat = 1.6,
                                            duration: Double = 1.9,
                                            intensity: Double = 1.0) -> some View {
        modifier(PixioCometGlow(shape: shape, themeColor: themeColor,
                                lineWidth: lineWidth, duration: duration, intensity: intensity))
    }
}

// MARK: - Input Bar

private struct ChatInput: View {
    let viewModel: ChatViewModel
    var isInputFocused: FocusState<Bool>.Binding
    var namespace: Namespace.ID
    var isPlusPopoutOpen: Bool = false
    var onPlusTap: () -> Void = {}

    @State private var isListening: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera: Bool = false
    @State private var isLoadingImage: Bool = false

    private var canSend: Bool {
        let hasText = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || viewModel.hasPendingImage) && !viewModel.isStreaming
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pending image
            if viewModel.hasPendingImage {
                PendingImagePreview(
                    imageData: viewModel.pendingImageData,
                    onRemove: { viewModel.clearImageAttachment() }
                )
            }

            HStack(spacing: 10) {
                // Vita+ — opens VitaInputPopout (D4 anchored, substitui .sheet UIKit)
                Button {
                    onPlusTap()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(VitaColors.textPrimary)
                        .frame(width: 34, height: 34)
                        .pixioRaised(in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Vita+")
                .matchedGeometryEffect(id: "plus_popout_origin", in: namespace, isSource: !isPlusPopoutOpen)

                // Text input — tipografia legível canon
                TextField(
                    "Pergunte ao Vita...",
                    text: Binding(
                        get: { viewModel.inputText },
                        set: { viewModel.inputText = $0 }
                    ),
                    axis: .vertical
                )
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(VitaColors.textPrimary)
                .tint(VitaColors.accent)
                .lineLimit(1...4)
                .focused(isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    isInputFocused.wrappedValue = false
                    Task { await viewModel.send() }
                }

                // Mic — Vita's existing carved button
                VitaMicButton(isListening: $isListening) { transcribed in
                    if viewModel.inputText.isEmpty {
                        viewModel.inputText = transcribed
                    } else {
                        viewModel.inputText += " " + transcribed
                    }
                }

                // Send — D4 gold quando ativo, glass neutro quando idle.
                Button {
                    isInputFocused.wrappedValue = false
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(canSend ? VitaColors.surface : VitaColors.textTertiary)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(
                                    canSend
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [VitaColors.accent, VitaColors.accentHover],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        : AnyShapeStyle(.ultraThinMaterial)
                                )
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            Circle().stroke(
                                canSend ? VitaColors.accentHover.opacity(0.5) : VitaColors.glassBorder,
                                lineWidth: 1
                            )
                        )
                        .shadow(color: canSend ? VitaColors.accent.opacity(0.35) : .clear, radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .animation(.easeInOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // Composer — fundo escuro pra contraste + glow "cometa" girando em
            // volta (mesmo efeito do card "Pensando", mas DEVAGAR e SUTIL,
            // premium, não distrai). Canon Pixio 2026-06-10.
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.black.opacity(0.35))
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            )
            .pixioCometGlow(RoundedRectangle(cornerRadius: 22, style: .continuous),
                            themeColor: PixioCoState.shared.activeThemeColor.color,
                            lineWidth: 1.2, duration: 6.5, intensity: 0.6)
            .shadow(color: VitaColors.accent.opacity(0.30), radius: 18, x: 0, y: 0)
            .shadow(color: VitaColors.accent.opacity(0.18), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .padding(.top, 8)
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            isLoadingImage = true
            Task {
                defer { isLoadingImage = false; selectedPhotoItem = nil }
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.setImageAttachment(data: data, mimeType: newItem.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg")
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { imageData in
                if let imageData { viewModel.setImageAttachment(data: imageData, mimeType: "image/jpeg") }
                showCamera = false
            }
        }
        // VitaInputPopout substituiu .sheet — estado gerenciado em VitaChatScreen
    }
}

// MARK: - Pending Image Preview

private struct PendingImagePreview: View {
    let imageData: Data?
    let onRemove: () -> Void

    var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            HStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.glassBorder, lineWidth: 1)
                        )
                    Button(action: onRemove) {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.7)).frame(width: 20, height: 20)
                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundColor(VitaColors.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -5)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
    }
}

// MARK: - Camera Capture

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data?) -> Void
        init(onCapture: @escaping (Data?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image.jpegData(compressionQuality: 0.8))
            } else { onCapture(nil) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCapture(nil) }
    }
}
