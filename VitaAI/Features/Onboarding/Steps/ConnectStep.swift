import SwiftUI

// MARK: - Connect Content (dynamic portals from university data + all known types from API)

struct ConnectStep: View {
    var university: University?
    var allPortalTypes: [PortalTypeInfo]  // All distinct portal types from API
    var onConnect: ((String) -> Void)?
    @State private var showAllConnectors = false

    private var detectedPortalTypes: Set<String> {
        Set(university?.allDetectedPortals.map(\.portalType) ?? [])
    }

    /// Portal types not detected for current university (for "Outros portais" section)
    private var otherPortalTypes: [PortalTypeInfo] {
        let excluded = detectedPortalTypes
        return allPortalTypes.filter { !excluded.contains($0.type) }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Detected portals from university data
            if let uni = university {
                let detected = uni.allDetectedPortals
                if !detected.isEmpty {
                    ForEach(uni.academicPortals) { portal in
                        ConnectorCard(
                            letter: University.letter(for: portal.portalType),
                            name: portal.displayName.isEmpty ? University.displayName(for: portal.portalType) : portal.displayName,
                            status: String(localized: "onboarding_connect_detected"),
                            color: University.color(for: portal.portalType),
                            isPrimary: portal.isPrimary,
                            onTap: { onConnect?(portal.portalType) }
                        )
                    }
                    ForEach(uni.lmsPortals) { portal in
                        ConnectorCard(
                            letter: University.letter(for: portal.portalType),
                            name: portal.displayName.isEmpty ? University.displayName(for: portal.portalType) : portal.displayName,
                            status: String(localized: "onboarding_connect_detected"),
                            color: University.color(for: portal.portalType),
                            isPrimary: portal.isPrimary,
                            onTap: { onConnect?(portal.portalType) }
                        )
                    }
                }
            }

            // Google connectors
            ConnectorCard(
                letter: "G", name: "Google Calendar", status: String(localized: "onboarding_connect_available"),
                color: Color(red: 0.26, green: 0.52, blue: 0.96), isPrimary: false,
                onTap: { onConnect?("google_calendar") }
            )
            ConnectorCard(
                letter: "G", name: "Google Drive", status: String(localized: "onboarding_connect_available"),
                color: Color(red: 0.13, green: 0.59, blue: 0.33), isPrimary: false,
                onTap: { onConnect?("google_drive") }
            )

            // Show all connectors button (other portal types from API)
            if !showAllConnectors && !otherPortalTypes.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) { showAllConnectors = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle").font(.system(size: 13))
                        Text(String(localized: "onboarding_connect_other_portals"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if showAllConnectors {
                ForEach(otherPortalTypes) { portal in
                    ConnectorCard(
                        letter: portal.letter,
                        name: portal.displayName,
                        status: String(localized: "onboarding_connect_available"),
                        color: portal.color,
                        isPrimary: false,
                        onTap: { onConnect?(portal.type) }
                    )
                }
            }
        }
    }
}

// MARK: - Portal Type Info (derived from API data)

struct PortalTypeInfo: Identifiable {
    var id: String { type }
    let type: String
    let displayName: String
    let letter: String
    let color: Color

    /// Build from a portal type string using University helpers (fallback)
    init(type: String) {
        self.type = type
        self.displayName = University.displayName(for: type)
        self.letter = University.letter(for: type)
        self.color = University.color(for: type)
    }
}

// MARK: - Connector Card (tappable)

private struct ConnectorCard: View {
    let letter: String
    let name: String
    let status: String
    let color: Color
    var isPrimary: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 14) {
                Text(letter)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.2)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    HStack(spacing: 4) {
                        Circle().fill(isPrimary ? color : .white.opacity(0.3)).frame(width: 5, height: 5)
                        Text(status)
                            .font(.system(size: 11))
                            .foregroundStyle(isPrimary ? color.opacity(0.8) : .white.opacity(0.4))
                    }
                }

                Spacer()

                Text(String(localized: "onboarding_connect_button"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isPrimary ? color : VitaColors.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).stroke((isPrimary ? color : VitaColors.accent).opacity(0.3), lineWidth: 1))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isPrimary ? color.opacity(0.04) : Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(isPrimary ? color.opacity(0.12) : Color.white.opacity(0.06), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
