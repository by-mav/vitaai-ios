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
                            status: .disconnected,
                            color: University.color(for: portal.portalType),
                            isPrimary: portal.isPrimary,
                            onConnect: { onConnect?(portal.portalType) }
                        )
                    }
                    ForEach(uni.lmsPortals) { portal in
                        ConnectorCard(
                            letter: University.letter(for: portal.portalType),
                            name: portal.displayName.isEmpty ? University.displayName(for: portal.portalType) : portal.displayName,
                            status: .disconnected,
                            color: University.color(for: portal.portalType),
                            isPrimary: portal.isPrimary,
                            onConnect: { onConnect?(portal.portalType) }
                        )
                    }
                }
            }

            // Google connectors
            ConnectorCard(
                letter: "G", name: "Google Calendar",
                status: .disconnected,
                color: Color(red: 0.26, green: 0.52, blue: 0.96),
                onConnect: { onConnect?("google_calendar") }
            )
            ConnectorCard(
                letter: "G", name: "Google Drive",
                status: .disconnected,
                color: Color(red: 0.13, green: 0.59, blue: 0.33),
                onConnect: { onConnect?("google_drive") }
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
                        status: .disconnected,
                        color: portal.color,
                        onConnect: { onConnect?(portal.type) }
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
