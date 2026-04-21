import SwiftUI

// MARK: - VitaNotifPopout
// Glass notification popout — 60% width, anchored top-trailing below TopNav
// Shows 5 visible items with scroll indicator bar

struct VitaNotifPopout: View {
    let onDismiss: () -> Void
    let onSettingsTap: () -> Void
    let onNavigate: (String) -> Void

    @Environment(\.appContainer) private var container
    @ObservedObject private var pushManager = PushManager.shared
    @State private var notifications: [VitaNotification] = []
    @State private var isVisible = false
    @State private var timeRefreshTick = false
    private let timeRefreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var unreadCount: Int {
        notifications.filter { !$0.read }.count
    }

    private var hasMoreThanVisible: Bool {
        notifications.count > 5
    }

    var body: some View {
        let _ = timeRefreshTick
        ZStack(alignment: .topTrailing) {
            // Dismiss backdrop — fills all content area
            Color.black.opacity(0.001)
                .onTapGesture { dismiss() }

            // Bubble — top trailing, below TopNav
            popoutContent
                .padding(.trailing, 12)
                .padding(.top, 4)
                .scaleEffect(isVisible ? 1 : 0.88, anchor: .topTrailing)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : -12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Instant: use cached notifications (already fetched by PushManager)
            notifications = pushManager.cachedNotifications
            withAnimation(.spring(duration: 0.3, bounce: 0.12)) {
                isVisible = true
            }
            // Background refresh for freshness
            Task {
                await PushManager.shared.refreshUnreadCount()
                notifications = pushManager.cachedNotifications
            }
        }
        .onReceive(timeRefreshTimer) { _ in
            timeRefreshTick.toggle()
        }
    }

    // MARK: - Popout Content

    private var popoutContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("Notificações")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VitaColors.surface)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(VitaColors.accentHover)
                        )
                }

                Spacer()

                if unreadCount > 0 {
                    Button(action: { markAllRead() }) {
                        Text("Marcar lidas")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VitaColors.accentHover.opacity(0.90))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { dismiss(); onSettingsTap() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle()
                .fill(VitaColors.accentLight.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 10)

            if notifications.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 3) {
                        ForEach(notifications) { item in
                            Button {
                                tapNotification(item)
                            } label: {
                                notifRow(item)
                            }
                            .buttonStyle(NotifButtonStyle())
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.visible)
                .frame(maxHeight: notifListHeight)
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.78)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.055, green: 0.043, blue: 0.035).opacity(0.97),
                            Color(red: 0.039, green: 0.031, blue: 0.024).opacity(0.98)
                        ],
                        startPoint: .init(x: 0.5, y: 0),
                        endPoint: .init(x: 0.48, y: 1)
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(VitaColors.accentHover.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 16)
                .shadow(color: VitaColors.accent.opacity(0.06), radius: 10, x: 0, y: 0)
        )
    }

    /// Height for ~5 visible notification rows
    private var notifListHeight: CGFloat {
        let rowHeight: CGFloat = 70
        let visibleCount = min(notifications.count, 5)
        return CGFloat(visibleCount) * rowHeight + 16
    }

    // MARK: - Notification Row (tappable)

    private func notifRowButton(_ item: VitaNotification) -> some View {
        Button {
            NSLog("[NotifPopout] TAP on: %@ route=%@", item.title, item.route ?? "nil")
            tapNotification(item)
        } label: {
            notifRow(item)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func notifRow(_ item: VitaNotification) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(item.icon)
                .font(.system(size: 18))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.read ? Color.white.opacity(0.68) : Color.white.opacity(0.96))
                    .lineLimit(1)

                Text(item.description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(item.read ? 0.55 : 0.80))
                    .lineLimit(2)
            }

            Spacer()

            Text(item.relativeTime)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.50))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.071, green: 0.055, blue: 0.039).opacity(0.60),
                            Color(red: 0.055, green: 0.043, blue: 0.031).opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            item.read
                                ? VitaColors.accentHover.opacity(0.04)
                                : VitaColors.accentHover.opacity(0.12),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.system(size: 24))
                .foregroundStyle(VitaColors.textTertiary)
            Text("Tudo em dia!")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.80))
            Text("Nenhuma notificação.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Actions

    private func tapNotification(_ item: VitaNotification) {
        if !item.read {
            if let idx = notifications.firstIndex(where: { $0.id == item.id }) {
                var updated = notifications
                let old = updated[idx]
                updated[idx] = VitaNotification(id: old.id, type: old.type, title: old.title, description: old.description, time: old.time, read: true, createdAt: old.createdAt)
                withAnimation(.easeInOut(duration: 0.2)) {
                    notifications = updated
                }
                // Sync cache immediately so reopening popout won't flash unread
                pushManager.updateCachedNotifications(updated)
            }
            Task {
                try? await container.api.markNotificationsRead(ids: [item.id])
                await pushManager.refreshUnreadCount()
            }
        }
        if let route = item.route, !route.isEmpty {
            onNavigate(route)
        }
    }

    private func markAllRead() {
        let updated = notifications.map {
            VitaNotification(id: $0.id, type: $0.type, title: $0.title, description: $0.description, time: $0.time, read: true, createdAt: $0.createdAt)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            notifications = updated
        }
        // Sync cache immediately
        pushManager.updateCachedNotifications(updated)
        Task {
            try? await container.api.markNotificationsRead(markAll: true)
            await pushManager.refreshUnreadCount()
        }
    }

    private func deleteNotification(_ item: VitaNotification) {
        withAnimation(.easeOut(duration: 0.2)) {
            notifications.removeAll { $0.id == item.id }
        }
        // Mark as read on backend (no delete endpoint yet)
        Task {
            try? await container.api.markNotificationsRead(ids: [item.id])
        }
    }

    private func dismiss() {
        withAnimation(.spring(duration: 0.3, bounce: 0.12)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Notif Button Style (no flash, full hit area)

private struct NotifButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .contentShape(Rectangle())
    }
}

// MARK: - Swipe to Delete (notification-specific)

private struct SwipeToDelete<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = -70

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer()
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 56)
            }
            .background(VitaColors.dataRed.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(offset < -20 ? 1 : 0)

            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = value.translation.width * 0.6
                            }
                        }
                        .onEnded { _ in
                            if offset < threshold {
                                withAnimation(.easeOut(duration: 0.2)) { offset = -300 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onDelete()
                                }
                            } else {
                                withAnimation(.spring(duration: 0.25)) { offset = 0 }
                            }
                        }
                )
        }
    }
}
