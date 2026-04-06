import SwiftUI

// MARK: - ConnectorStatusSheet
// Shared bottom sheet for connected services. Shows icon, stats, sync/disconnect buttons.
// Replaces ConnectionsScreen's private ConnectedServiceSheet — now public and reusable.

struct ConnectorStatusSheet: View {
    let serviceName: String
    let icon: String
    var subtitle: String?
    let lastSync: String?
    let stats: [ConnectorStat]
    var syncNote: String?
    let onSync: () -> Void
    let onDisconnect: () -> Void

    private let goldPrimary = VitaColors.accentHover
    private let goldAccent = VitaColors.accent
    private let goldSubtle = VitaColors.accentLight

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.10))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle().stroke(Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.25), lineWidth: 1)
                            )
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 0.29, green: 0.87, blue: 0.50))
                    }
                    .padding(.top, 24)

                    Spacer().frame(height: 16)

                    Text("\(serviceName) Conectado")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.92))

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(goldSubtle.opacity(0.35))
                            .padding(.top, 4)
                    }

                    if let lastSync {
                        Text("Ultima sincronizacao: \(lastSync)")
                            .font(.system(size: 12))
                            .foregroundColor(goldSubtle.opacity(0.30))
                            .padding(.top, 4)
                    }

                    if let syncNote {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 9))
                            Text(syncNote)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.60))
                        .padding(.top, 6)
                    }

                    // Stats pills
                    if !stats.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(stats.indices, id: \.self) { i in
                                if i > 0 {
                                    Rectangle()
                                        .fill(goldSubtle.opacity(0.08))
                                        .frame(width: 1, height: 32)
                                }
                                statPill(stats[i])
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white.opacity(0.025))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    }

                    // Sync button
                    Button(action: onSync) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .medium))
                            Text("Sincronizar Agora")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.031, green: 0.024, blue: 0.039))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [goldPrimary, goldAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    // Disconnect button
                    Button(action: onDisconnect) {
                        HStack(spacing: 6) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 13))
                                .rotationEffect(.degrees(45))
                            Text("Desconectar \(serviceName)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(goldSubtle.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func statPill(_ item: ConnectorStat) -> some View {
        VStack(spacing: 2) {
            Text("\(item.value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.white.opacity(0.88))
            Text(item.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(goldSubtle.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ConnectorStat

struct ConnectorStat {
    let value: Int
    let label: String
}
