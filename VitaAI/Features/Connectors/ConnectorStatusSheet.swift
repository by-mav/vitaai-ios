import SwiftUI

// MARK: - ConnectorStatusSheet

struct ConnectorStatusSheet: View {
    let serviceName: String
    let iconAsset: String
    var subtitle: String?
    let lastSync: String?
    var lastSyncAbsolute: String?
    var lastPing: String?
    var isStale = false
    var isExpired = false
    let stats: [ConnectorStat]
    let onSync: () -> Void
    let onDisconnect: () -> Void

    @State private var showsDisconnectAlert = false

    var body: some View {
        VitaSheet(detents: [.medium, .large]) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: VitaTokens.Spacing.xl) {
                    identity
                    syncState

                    if !stats.isEmpty {
                        statsRow
                    }

                    VStack(spacing: VitaTokens.Spacing.sm) {
                        VitaButton(
                            text: String(localized: "connector_action_sync_now"),
                            action: onSync,
                            variant: .primary,
                            size: .md,
                            leadingSystemImage: "arrow.triangle.2.circlepath",
                            fillsWidth: true
                        )
                        .accessibilityIdentifier("connectorStatusSync_\(serviceName)")

                        VitaButton(
                            text: String(
                                format: String(localized: "connector_action_disconnect_format"),
                                serviceName
                            ),
                            action: { showsDisconnectAlert = true },
                            variant: .ghost,
                            size: .md,
                            leadingSystemImage: "link.badge.minus",
                            fillsWidth: true
                        )
                        .accessibilityIdentifier("connectorStatusDisconnect_\(serviceName)")
                    }
                }
                .padding(.horizontal, VitaTokens.Spacing.xl)
                .padding(.top, VitaTokens.Spacing._2xl)
                .padding(.bottom, VitaTokens.Spacing._4xl)
            }
        }
        .vitaAlert(
            isPresented: $showsDisconnectAlert,
            title: String(localized: "connector_disconnect_title"),
            message: String(
                format: String(localized: "connector_disconnect_message_format"),
                serviceName
            ),
            destructiveLabel: String(localized: "connector_action_disconnect"),
            cancelLabel: String(localized: "connector_action_cancel"),
            onConfirm: onDisconnect
        )
    }

    private var identity: some View {
        VStack(spacing: VitaTokens.Spacing.sm) {
            Image(iconAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: VitaTokens.Radius.lg,
                        style: .continuous
                    )
                )
                .shadow(
                    color: VitaColors.accent.opacity(0.16),
                    radius: VitaTokens.Elevation.md,
                    y: VitaTokens.Elevation.xs
                )

            Text(
                String(
                    format: String(localized: "connector_status_connected_format"),
                    serviceName
                )
            )
            .font(VitaTypography.titleLarge)
            .foregroundStyle(VitaColors.textPrimary)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var syncState: some View {
        if lastSync != nil || lastPing != nil {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                if let lastSync {
                    metadataRow(
                        icon: isExpired || isStale
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.circle.fill",
                        text: String(
                            format: String(localized: "connector_data_synced_format"),
                            lastSync
                        ),
                        color: isExpired || isStale
                            ? VitaColors.dataAmber
                            : VitaColors.success
                    )
                }

                if let lastSyncAbsolute {
                    metadataRow(
                        icon: "clock",
                        text: lastSyncAbsolute,
                        color: VitaColors.textSecondary
                    )
                }

                if let lastPing {
                    metadataRow(
                        icon: "bolt.fill",
                        text: String(
                            format: String(localized: "connector_token_verified_format"),
                            lastPing
                        ),
                        color: VitaColors.success
                    )
                }

                if isStale && !isExpired {
                    metadataRow(
                        icon: "arrow.triangle.2.circlepath",
                        text: String(localized: "connector_sync_stale"),
                        color: VitaColors.dataAmber
                    )
                }
            }
            .padding(VitaTokens.Spacing.lg)
            .vitaGlassCard(cornerRadius: VitaTokens.Radius.lg)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            ForEach(stats.indices, id: \.self) { index in
                if index > 0 {
                    Rectangle()
                        .fill(VitaColors.glassBorder)
                        .frame(width: 1, height: VitaTokens.Spacing._3xl)
                }

                VStack(spacing: VitaTokens.Spacing.xs) {
                    Text("\(stats[index].value)")
                        .font(VitaTypography.headlineSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                        .monospacedDigit()
                    Text(stats[index].label)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, VitaTokens.Spacing.lg)
        .vitaGlassCard(cornerRadius: VitaTokens.Radius.lg)
    }

    private func metadataRow(icon: String, text: String, color: Color) -> some View {
        Label {
            Text(text)
                .font(VitaTypography.bodySmall)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .font(VitaTypography.labelSmall)
        }
        .foregroundStyle(color)
    }
}

struct ConnectorStat {
    let value: Int
    let label: String
}
