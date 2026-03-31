import SwiftUI

// MARK: - Atlas teal palette (from atlas3d-mobile-v1.html)
// .teal-accent  rgba(94,234,212,0.90)
// .teal-muted   rgba(94,234,212,0.50)
// atlasBg       rgba(20,184,166)

private extension Color {
    static let atlasTeal    = Color(red: 94/255,  green: 234/255, blue: 212/255)
    static let atlasGreen   = Color(red: 20/255,  green: 184/255, blue: 166/255)
    static let atlasDeepBg  = Color(red: 8/255,   green: 6/255,   blue: 10/255)
    static let atlasCardBg  = Color(red: 12/255,  green: 9/255,   blue: 7/255)
}

// MARK: - Data

private let bodySystems = [
    "Esqueleto", "Muscular", "Nervoso",
    "Cardiovascular", "Digestório", "Respiratório"
]

private struct AnatomicalStructure: Identifiable {
    let id = UUID()
    let name: String
    let meta: String
    let icon: String  // SF Symbol
}

private let skeletonStructures: [AnatomicalStructure] = [
    .init(name: "Crânio",             meta: "22 ossos - Cabeça",             icon: "oval"),
    .init(name: "Coluna Vertebral",   meta: "33 vértebras - Tronco",         icon: "list.dash"),
    .init(name: "Caixa Torácica",     meta: "12 pares de costelas - Tronco", icon: "oval.portrait"),
    .init(name: "Membros Superiores", meta: "Úmero, rádio, ulna - Braço",   icon: "figure.arms.open"),
    .init(name: "Pelve",              meta: "Ilíaco, sacro, cóccix - Quadril", icon: "rhombus"),
    .init(name: "Membros Inferiores", meta: "Fêmur, tíbia, fíbula - Perna", icon: "figure.walk"),
]

// MARK: - AtlasWebViewScreen

struct AtlasWebViewScreen: View {
    var onBack: () -> Void

    @State private var selectedSystem = "Esqueleto"
    @State private var searchText    = ""

    var body: some View {
        ZStack {
            Color.atlasDeepBg.ignoresSafeArea()

            VStack(spacing: 0) {
                topNav
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        viewer3D
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        systemTabs
                            .padding(.top, 14)

                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 14)

                        structuresSection
                            .padding(.top, 18)
                    }
                    .padding(.bottom, 110)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Top Nav

    private var topNav: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(VitaColors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar")

            VStack(alignment: .leading, spacing: 1) {
                Text("Atlas 3D")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(VitaColors.textPrimary)
                Text("Anatomia interativa")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.atlasTeal.opacity(0.40))
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(VitaColors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Compartilhar")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.atlasDeepBg)
    }

    // MARK: - 3D Viewer (280px placeholder)

    private var viewer3D: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background layers
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 8/255,  green: 12/255, blue: 14/255).opacity(0.95), location: 0),
                            .init(color: Color(red: 6/255,  green: 8/255,  blue: 10/255),               location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    ZStack {
                        RadialGradient(
                            colors: [Color.atlasGreen.opacity(0.12), .clear],
                            center: UnitPoint(x: 0.50, y: 0.40),
                            startRadius: 0, endRadius: 140
                        )
                        RadialGradient(
                            colors: [Color.atlasGreen.opacity(0.06), .clear],
                            center: UnitPoint(x: 0.30, y: 0.70),
                            startRadius: 0, endRadius: 100
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.atlasTeal.opacity(0.10), lineWidth: 1)
                }

            // Skeleton placeholder + hint
            VStack(spacing: 12) {
                skeletonWireframe
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                        .foregroundColor(Color.atlasTeal.opacity(0.35))
                    Text("Toque e arraste para girar")
                        .font(.system(size: 10))
                        .foregroundColor(Color.atlasTeal.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Zoom controls — bottom-right
            HStack(spacing: 6) {
                ctrlButton(systemName: "plus")
                ctrlButton(systemName: "minus")
                ctrlButton(systemName: "arrow.counterclockwise")
            }
            .padding(12)
        }
        .frame(height: 280)
        .shadow(color: .black.opacity(0.50), radius: 25, x: 0, y: 20)
    }

    private var skeletonWireframe: some View {
        ZStack {
            // Body silhouette
            Capsule()
                .fill(Color.atlasTeal.opacity(0.03))
                .frame(width: 120, height: 180)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.atlasTeal.opacity(0.15), lineWidth: 2)
                )
            // Torso
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(Color.atlasTeal.opacity(0.08), lineWidth: 1)
                .frame(width: 86, height: 108)
                .offset(y: 12)
            // Head
            Circle()
                .strokeBorder(Color.atlasTeal.opacity(0.12), lineWidth: 1.5)
                .frame(width: 30, height: 30)
                .offset(y: -62)
        }
    }

    private func ctrlButton(systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.40))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.atlasTeal.opacity(0.12), lineWidth: 1)
                )
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.atlasTeal.opacity(0.65))
        }
        .frame(width: 32, height: 32)
    }

    // MARK: - Body System Tabs

    private var systemTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(bodySystems, id: \.self) { system in
                    let active = selectedSystem == system
                    Button { selectedSystem = system } label: {
                        Text(system)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(
                                active
                                    ? Color.atlasTeal.opacity(0.85)
                                    : VitaColors.textWarm.opacity(0.35)
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(active ? Color.atlasGreen.opacity(0.12) : Color.white.opacity(0.06))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                active
                                                    ? Color.atlasTeal.opacity(0.20)
                                                    : VitaColors.textWarm.opacity(0.06),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: selectedSystem)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color.atlasTeal.opacity(0.40))
            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("Buscar estrutura anatômica...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(VitaColors.textWarm.opacity(0.25))
                }
                TextField("", text: $searchText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VitaColors.white.opacity(0.85))
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            searchText.isEmpty
                                ? VitaColors.textWarm.opacity(0.06)
                                : Color.atlasTeal.opacity(0.20),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Structures Section

    private var structuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estruturas - \(selectedSystem)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(VitaColors.textWarm.opacity(0.35))
                .tracking(0.8)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, structure in
                    structureRow(structure, isLast: index == filtered.count - 1)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.atlasCardBg.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                Color(red: 1, green: 232/255, blue: 194/255).opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 16)
        }
    }

    private var filtered: [AnatomicalStructure] {
        guard !searchText.isEmpty else { return skeletonStructures }
        return skeletonStructures.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.meta.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func structureRow(_ s: AnatomicalStructure, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.atlasGreen.opacity(0.14), Color.atlasGreen.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.atlasTeal.opacity(0.10), lineWidth: 1)
                    )
                Image(systemName: s.icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color.atlasTeal.opacity(0.65))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(s.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VitaColors.white.opacity(0.88))
                Text(s.meta)
                    .font(.system(size: 10))
                    .foregroundColor(VitaColors.textWarm.opacity(0.30))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(VitaColors.textWarm.opacity(0.15))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            if !isLast {
                VitaColors.textWarm.opacity(0.03)
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("AtlasWebViewScreen") {
    AtlasWebViewScreen(onBack: {})
        .preferredColorScheme(.dark)
}
#endif
