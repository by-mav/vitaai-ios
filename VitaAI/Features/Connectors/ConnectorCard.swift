import SwiftUI

// MARK: - ConnectorCard
// Shared card used by ConnectionsScreen, Onboarding ConnectStep, and any future connector entry point.
// Mirrors Android's ConnectorCard composable and web's connector-card component.

struct ConnectorCard: View {
    let letter: String
    let name: String
    let status: ConnectionItemStatus
    let color: Color
    var lastSync: String?
    var stats: [(value: Int, label: String)] = []
    var isPrimary: Bool = false
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?
    var onTapConnected: (() -> Void)?

    // Design tokens (gold palette — matches ConnectionsScreen)
    private let goldSubtle = VitaColors.accentLight
    private let borderColor = VitaColors.glassBorder
    private let cardBg = VitaColors.glassBg

    var body: some View {
        let isConnected = status == .connected

        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                letterIcon
                nameAndStatus(isConnected: isConnected)
                Spacer()
                actionArea(isConnected: isConnected)
            }
            .padding(14)

            // Meta row (when connected)
            if isConnected, hasMetaData {
                metaRow
            }
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
        .onTapGesture {
            if isConnected { onTapConnected?() }
        }
    }

    // MARK: - Letter Icon

    private var letterIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.22))
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.18), lineWidth: 1)
                )
            Text(letter)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color.opacity(0.90))
        }
    }

    // MARK: - Name + Status

    private func nameAndStatus(isConnected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.90))

            HStack(spacing: 6) {
                Circle()
                    .fill(
                        isConnected
                            ? Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.75)
                            : Color.white.opacity(0.12)
                    )
                    .frame(width: 7, height: 7)
                    .shadow(color: isConnected ? Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.30) : .clear, radius: 3)
                Text(statusLabel)
                    .font(.system(size: 10.5))
                    .foregroundColor(statusLabelColor)
            }
        }
    }

    private var statusLabel: String {
        switch status {
        case .connected: "Conectado"
        case .expired: "Expirado"
        case .disconnected: isPrimary ? "Detectado" : "Disponível"
        case .loading: "Carregando..."
        }
    }

    private var statusLabelColor: Color {
        switch status {
        case .connected: Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.65)
        case .expired: VitaColors.dataAmber.opacity(0.65)
        default: isPrimary ? color.opacity(0.8) : goldSubtle.opacity(0.35)
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionArea(isConnected: Bool) -> some View {
        Button {
            if isConnected { onDisconnect?() }
            else { onConnect?() }
        } label: {
            Text(isConnected ? "Desconectar" : "Conectar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(
                    isConnected
                        ? Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.70)
                        : isPrimary ? color : Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.80)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isConnected
                        ? Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.06)
                        : (isPrimary ? color : VitaColors.glassInnerLight).opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(
                        isConnected
                            ? Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.12)
                            : (isPrimary ? color : Color(red: 1.0, green: 0.784, blue: 0.471)).opacity(0.16),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Meta Row

    private var hasMetaData: Bool {
        lastSync != nil || stats.contains(where: { $0.value > 0 })
    }

    private var metaRow: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(goldSubtle.opacity(0.04))
                .frame(height: 1)

            HStack(spacing: 6) {
                if let sync = lastSync {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                        .foregroundColor(goldSubtle.opacity(0.25))
                    Text(sync)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.55))
                }

                if lastSync != nil && stats.contains(where: { $0.value > 0 }) {
                    Circle()
                        .fill(goldSubtle.opacity(0.20))
                        .frame(width: 3, height: 3)
                }

                ForEach(stats.indices, id: \.self) { i in
                    if stats[i].value > 0 {
                        HStack(spacing: 2) {
                            Text("\(stats[i].value)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.55))
                            Text(stats[i].label)
                                .font(.system(size: 10))
                                .foregroundColor(goldSubtle.opacity(0.30))
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
}
