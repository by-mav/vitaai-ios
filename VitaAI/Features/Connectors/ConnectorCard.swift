import SwiftUI
import UIKit

// MARK: - ConnectorCard

/// Canonical connector row shared by onboarding and Settings.
/// It owns the four user-visible states, destructive confirmation and a
/// compact layout that stays readable with Dynamic Type.
struct ConnectorCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let letter: String
    let name: String
    let status: ConnectionItemStatus
    let color: Color
    var iconAsset: String?
    var iconCornerRadius: CGFloat? = VitaTokens.Radius.md
    var subtitle: String?
    var lastSync: String?
    var lastPing: String?
    var isStale = false
    var stats: [(value: Int, label: String)] = []
    var isPrimary = false
    var actionAccessibilityIdentifier: String?
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?
    var onTapConnected: (() -> Void)?

    @State private var showsDisconnectConfirmation = false

    private var isActive: Bool {
        status == .connected || status == .expired
    }

    private var stateColor: Color {
        switch status {
        case .connected: VitaColors.success
        case .expired: VitaColors.dataAmber
        case .disconnected, .loading: VitaColors.textTertiary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: VitaTokens.Spacing.md) {
                Group {
                    if isActive {
                        Button {
                            onTapConnected?()
                        } label: {
                            connectorIdentity
                        }
                        .buttonStyle(.plain)
                    } else {
                        connectorIdentity
                    }
                }

                actionButton
            }
            .padding(VitaTokens.Spacing.lg)

            if hasMetadata {
                metadata
            }
        }
        .vitaGlassCard(cornerRadius: VitaTokens.Radius.lg)
        .vitaAlert(
            isPresented: $showsDisconnectConfirmation,
            title: String(localized: "connector_disconnect_title"),
            message: String(
                format: String(localized: "connector_disconnect_message_format"),
                name
            ),
            destructiveLabel: String(localized: "connector_action_disconnect"),
            cancelLabel: String(localized: "connector_action_cancel"),
            onConfirm: { onDisconnect?() }
        )
        .accessibilityElement(children: .contain)
    }

    private var connectorIdentity: some View {
        HStack(spacing: VitaTokens.Spacing.md) {
            connectorIcon
            titleBlock
            Spacer(minLength: VitaTokens.Spacing.xs)
        }
        .contentShape(Rectangle())
    }

    private var connectorIcon: some View {
        Group {
            if let iconAsset, UIImage(named: iconAsset) != nil {
                Image(iconAsset)
                    .resizable()
                    .scaledToFit()
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: iconCornerRadius ?? VitaTokens.Radius.md,
                            style: .continuous
                        )
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                        .fill(color.opacity(0.16))
                        .overlay {
                            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                                .stroke(color.opacity(0.20), lineWidth: 1)
                        }
                    Text(letter)
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(color)
                }
            }
        }
        .frame(width: VitaTokens.Spacing._3xl, height: VitaTokens.Spacing._3xl)
        .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
            Text(name)
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: VitaTokens.Spacing.xs) {
                Group {
                    if status == .loading {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(VitaColors.accent)
                    } else {
                        Circle()
                            .fill(stateColor)
                    }
                }
                .frame(width: VitaTokens.Spacing.xs, height: VitaTokens.Spacing.xs)

                Text(statusLabel)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(stateColor)
            }
        }
    }

    private var statusLabel: String {
        switch status {
        case .connected: String(localized: "connector_status_connected")
        case .expired: String(localized: "connector_status_expired")
        case .disconnected:
            String(localized: isPrimary ? "connector_status_detected" : "connector_status_available")
        case .loading: String(localized: "connector_status_loading")
        }
    }

    private var actionButton: some View {
        Button {
            switch status {
            case .connected:
                showsDisconnectConfirmation = true
            case .expired, .disconnected:
                onConnect?()
            case .loading:
                break
            }
        } label: {
            Group {
                if status == .loading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(VitaColors.accent)
                } else {
                    Text(actionLabel)
                        .font(VitaTypography.labelMedium)
                }
            }
            .foregroundStyle(actionColor)
            .padding(.horizontal, VitaTokens.Spacing.md)
            .frame(minHeight: VitaTokens.Spacing._3xl)
            .background(actionColor.opacity(0.10))
            .overlay {
                RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous)
                    .stroke(actionColor.opacity(0.22), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(status == .loading)
        .accessibilityIdentifier(actionAccessibilityIdentifier ?? "connectorAction_\(name)")
    }

    private var actionLabel: String {
        switch status {
        case .connected: String(localized: "connector_action_disconnect")
        case .expired: String(localized: "connector_action_reconnect")
        case .disconnected: String(localized: "connector_action_connect")
        case .loading: String(localized: "connector_status_loading")
        }
    }

    private var actionColor: Color {
        switch status {
        case .connected: VitaColors.dataRed
        case .expired: VitaColors.dataAmber
        case .disconnected, .loading: isPrimary ? color : VitaColors.accentLight
        }
    }

    private var hasMetadata: Bool {
        lastSync != nil || stats.contains(where: { $0.value > 0 }) || (isStale && status == .connected)
    }

    private var visibleStats: [(value: Int, label: String)] {
        stats.filter { $0.value > 0 }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            Divider()
                .overlay(VitaColors.glassBorder)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: VitaTokens.Spacing.sm) {
                    syncMetadata
                    statsMetadata
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                    syncMetadata
                    statsMetadata
                }
            }

            if isStale, status == .connected {
                Label(
                    String(localized: "connector_sync_stale"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.dataAmber)
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.bottom, VitaTokens.Spacing.md)
    }

    @ViewBuilder
    private var syncMetadata: some View {
        if let lastSync {
            Label {
                Text(
                    status == .expired
                        ? String(format: String(localized: "connector_sync_expired_format"), lastSync)
                        : lastSync
                )
            } icon: {
                Image(systemName: status == .expired ? "exclamationmark.triangle.fill" : "clock")
            }
            .font(VitaTypography.labelSmall)
            .foregroundStyle(status == .expired ? VitaColors.dataAmber : VitaColors.textSecondary)
        }
    }

    @ViewBuilder
    private var statsMetadata: some View {
        if !visibleStats.isEmpty {
            HStack(spacing: VitaTokens.Spacing.sm) {
                ForEach(visibleStats.indices, id: \.self) { index in
                    Text("\(visibleStats[index].value) \(visibleStats[index].label)")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
        }
    }
}
