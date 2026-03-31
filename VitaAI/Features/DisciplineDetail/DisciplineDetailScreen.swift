import SwiftUI

// MARK: - DisciplineDetailScreen
// Matches disciplina-detalhe-mobile-v1.html mockup.
// Sections: Hero (image+overlay+back), Badge, Prova Alert, Study Grid,
//           Conteudo da prova, Materiais (PDFs), Videos recomendados, Vita sugere.

struct DisciplineDetailScreen: View {
    let disciplineId: String
    let disciplineName: String

    var onBack: (() -> Void)?
    var onNavigateToFlashcards: ((String) -> Void)?
    var onNavigateToQBank: (() -> Void)?
    var onNavigateToSimulado: (() -> Void)?

    // Mockup colors
    private let goldText = VitaColors.accentLight       // → VitaColors.accentLight
    private let goldBorder = VitaColors.accentHover     // → VitaColors.accentHover
    private let subtleText = VitaColors.textWarm
    private let alertRed = Color(red: 1.0, green: 0.47, blue: 0.31)
    private let greenColor = Color(red: 0.51, green: 0.78, blue: 0.55)
    private let blueColor = Color(red: 0.47, green: 0.71, blue: 1.0)
    private let purpleColor = Color(red: 0.39, green: 0.24, blue: 0.71)

    // MARK: - Hero image name derived from discipline name
    private var heroImageName: String {
        let k = disciplineName.lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "pt_BR"))
            .filter { $0.isLetter || $0.isNumber || $0 == " " }
        let mapping: [(String, String)] = [
            ("farmacologia",  "disc-farmacologia"),
            ("patologia",     "disc-patologia-geral"),
            ("legal",         "disc-medicina-legal"),
            ("histologia",    "disc-histologia"),
            ("anatomia",      "disc-anatomia"),
            ("bioquimica",    "disc-bioquimica"),
            ("fisiologia",    "disc-fisiologia-1"),
        ]
        for (kw, asset) in mapping where k.contains(kw) { return asset }
        return "disc-interprofissional"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: - Hero
                heroSection

                // MARK: - Prova Alert
                provaAlertSection
                    .padding(.horizontal, 14)
                    .padding(.top, 16)

                // MARK: - Study Grid
                sectionLabel("O que estudar")
                    .padding(.top, 18)
                studyGrid
                    .padding(.horizontal, 14)

                // MARK: - Conteudo da prova
                sectionLabel("Conteúdo da prova")
                    .padding(.top, 18)
                contentSection
                    .padding(.horizontal, 14)

                // MARK: - Materiais
                sectionLabel("Matériais")
                    .padding(.top, 18)
                materiaisSection
                    .padding(.horizontal, 14)

                // MARK: - Videos
                sectionLabel("Videos recomendados")
                    .padding(.top, 18)
                videosSection
                    .padding(.leading, 14)

                // MARK: - Vita Sugere
                vitaSugereSection
                    .padding(.horizontal, 14)
                    .padding(.top, 18)

                Spacer().frame(height: 120)
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            // Hero image
            ZStack {
                // Discipline hero image (falls back to gradient if asset missing)
                Image(heroImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .brightness(-0.5)
                    .saturation(1.2)

                // Overlay — two gradient layers matching mockup CSS:
                // 1) vertical: top 10% → bottom 88%
                LinearGradient(
                    colors: [
                        Color(red: 0.031, green: 0.024, blue: 0.039).opacity(0.1),
                        Color(red: 0.031, green: 0.024, blue: 0.039).opacity(0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // 2) horizontal: left 50% → transparent at 60% width
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.031, green: 0.024, blue: 0.039).opacity(0.5), location: 0),
                        .init(color: .clear, location: 0.6)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                // Content at bottom
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // Period badge
                    HStack(spacing: 4) {
                        Circle()
                            .stroke(goldText.opacity(0.80), lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                        Text("3o Periodo")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(goldText.opacity(0.80))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.bottom, 8)

                    // Discipline name
                    Text(disciplineName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .tracking(-0.5)

                    // Professor info
                    Text("Prof. Dr. Marcos Ribeiro \u{00B7} Peso 4 \u{00B7} 60h")
                        .font(.system(size: 12))
                        .foregroundStyle(subtleText.opacity(0.45))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 14)
            .padding(.top, 50) // Safe area offset

            // Back button
            Button(action: { onBack?() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Voltar")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(subtleText.opacity(0.60))
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel("Voltar")
            .padding(.top, 64) // Status bar + padding
            .padding(.leading, 28)
        }
    }

    // MARK: - Prova Alert

    private var provaAlertSection: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                // Days counter
                VStack(spacing: 0) {
                    Text("12")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(alertRed.opacity(0.90))
                    Text("DIAS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(alertRed.opacity(0.55))
                        .tracking(0.5)
                }
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(
                        colors: [
                            alertRed.opacity(0.20),
                            Color(red: 0.78, green: 0.24, blue: 0.16).opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(alertRed.opacity(0.22), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("P2 \(disciplineName)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.90))
                    Text("8 de abril \u{00B7} 19:00 \u{00B7} Sala 302")
                        .font(.system(size: 10))
                        .foregroundStyle(subtleText.opacity(0.35))

                    // Topic pills
                    FlowLayout(spacing: 6) {
                        topicPill("Antibioticos")
                        topicPill("AINEs")
                        topicPill("Opioides")
                        topicPill("SNA")
                    }
                    .padding(.top, 4)
                }
            }
            .padding(14)
        }
    }

    private func topicPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(subtleText.opacity(0.55))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(subtleText.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Study Grid (2x2)

    private var studyGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            studyCard(
                icon: "questionmark.circle",
                iconBg: (goldText.opacity(0.18), goldText.opacity(0.08)),
                iconColor: goldText,
                iconBorderColor: goldBorder.opacity(0.18),
                value: "248",
                label: "Questões disponíveis",
                action: { onNavigateToQBank?() }
            )
            studyCard(
                icon: "desktopcomputer",
                iconBg: (purpleColor.opacity(0.28), purpleColor.opacity(0.12)),
                iconColor: Color(red: 0.71, green: 0.55, blue: 1.0),
                iconBorderColor: Color(red: 0.71, green: 0.47, blue: 1.0).opacity(0.18),
                value: "84",
                label: "Flashcards",
                action: { onNavigateToFlashcards?(disciplineId) }
            )
            studyCard(
                icon: "doc.text",
                iconBg: (blueColor.opacity(0.28), blueColor.opacity(0.12)),
                iconColor: blueColor,
                iconBorderColor: blueColor.opacity(0.18),
                value: "Gerar",
                label: "Resumo IA",
                isSmallValue: true,
                action: { }
            )
            studyCard(
                icon: "music.note",
                iconBg: (greenColor.opacity(0.28), greenColor.opacity(0.12)),
                iconColor: Color(red: 0.51, green: 0.86, blue: 0.63),
                iconBorderColor: greenColor.opacity(0.18),
                value: "Iniciar",
                label: "Simulado da matéria",
                isSmallValue: true,
                action: { onNavigateToSimulado?() }
            )
        }
    }

    private func studyCard(
        icon: String,
        iconBg: (Color, Color),
        iconColor: Color,
        iconBorderColor: Color,
        value: String,
        label: String,
        isSmallValue: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VitaGlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [iconBg.0, iconBg.1],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 34, height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(iconBorderColor, lineWidth: 1)
                            )
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(iconColor.opacity(0.90))
                    }

                    Text(value)
                        .font(.system(size: isSmallValue ? 16 : 20, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .tracking(-0.4)
                        .padding(.top, 10)

                    Text(label)
                        .font(.system(size: 10))
                        .foregroundStyle(subtleText.opacity(0.40))
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Topics

    private var contentSection: some View {
        VitaGlassCard {
            VStack(spacing: 0) {
                contentRow(
                    icon: "checkmark.circle",
                    title: "Antibioticos Beta-lactamicos",
                    subtitle: "Penicilinas, cefalosporinas, carbapenens",
                    badge: "74%",
                    badgeColor: greenColor
                )
                contentDivider
                contentRow(
                    icon: "checkmark.circle",
                    title: "Anti-inflamatorios (AINEs)",
                    subtitle: "COX-1/COX-2, ibuprofeno, naproxeno",
                    badge: "68%",
                    badgeColor: goldText
                )
                contentDivider
                contentRow(
                    icon: "exclamationmark.circle",
                    title: "Analgésicos Opióides",
                    subtitle: "Morfina, codeína, mecanismo mu/kappa",
                    badge: "42%",
                    badgeColor: alertRed
                )
                contentDivider
                contentRow(
                    icon: "plus.circle",
                    title: "SNA — Adrenergicos e Colinergicos",
                    subtitle: "Simpato/parasimpatoliticos e mimeticos",
                    badge: nil,
                    badgeColor: .clear,
                    trailingText: "Não iniciado"
                )
            }
        }
    }

    private func contentRow(
        icon: String,
        title: String,
        subtitle: String,
        badge: String?,
        badgeColor: Color,
        trailingText: String? = nil
    ) -> some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                goldText.opacity(0.12),
                                goldText.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(goldBorder.opacity(0.10), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(goldText.opacity(0.70))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(subtleText.opacity(0.35))
            }

            Spacer()

            if let badge = badge {
                Text(badge)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(badgeColor.opacity(0.80))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(badgeColor.opacity(0.18), lineWidth: 1))
            }
            if let text = trailingText {
                Text(text)
                    .font(.system(size: 10))
                    .foregroundStyle(subtleText.opacity(0.30))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var contentDivider: some View {
        Rectangle()
            .fill(subtleText.opacity(0.04))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - Materiais (PDFs)

    private var materiaisSection: some View {
        VitaGlassCard {
            VStack(spacing: 0) {
                pdfRow(name: "Resumo Antibioticos — Aula 12", meta: "PDF \u{00B7} 2.4 MB \u{00B7} Adicionado 18 mar")
                contentDivider
                pdfRow(name: "Slides AINEs — Prof. Ribeiro", meta: "PDF \u{00B7} 5.1 MB \u{00B7} Adicionado 12 mar")
                contentDivider
                pdfRow(name: "Mapa Mental Opióides", meta: "PDF \u{00B7} 1.8 MB \u{00B7} Adicionado 5 mar")

                // Upload button
                uploadRow
            }
        }
    }

    private func pdfRow(name: String, meta: String) -> some View {
        HStack(spacing: 12) {
            // PDF icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.94, green: 0.27, blue: 0.27).opacity(0.18),
                                Color(red: 0.78, green: 0.16, blue: 0.16).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 0.94, green: 0.27, blue: 0.27).opacity(0.15), lineWidth: 1)
                    )
                Image(systemName: "doc.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.47, blue: 0.39).opacity(0.80))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(meta)
                    .font(.system(size: 10))
                    .foregroundStyle(subtleText.opacity(0.35))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var uploadRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.doc")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(goldBorder.opacity(0.50))
            Text("Enviar material")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(goldBorder.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(goldBorder.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Videos Recomendados

    private var videosSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                videoCard(
                    title: "Antibioticos Beta-lactamicos — Mecanismo de Acao Completo",
                    channel: "Prof. Tiago Farmaco \u{00B7} 84K views",
                    duration: "12:34",
                    gradient: [goldText.opacity(0.15), Color(red: 0.31, green: 0.16, blue: 0.08).opacity(0.30)],
                    playColor: goldBorder.opacity(0.40)
                )
                videoCard(
                    title: "AINEs e Opióides — Resumo pra Prova",
                    channel: "MedResumos \u{00B7} 120K views",
                    duration: "18:21",
                    gradient: [purpleColor.opacity(0.15), Color(red: 0.16, green: 0.08, blue: 0.31).opacity(0.30)],
                    playColor: Color(red: 0.71, green: 0.55, blue: 1.0).opacity(0.40)
                )
                videoCard(
                    title: "Sistema Nervoso Autonomo — Aula Completa",
                    channel: "Sanar Medicina \u{00B7} 200K views",
                    duration: "25:08",
                    gradient: [Color(red: 0.24, green: 0.55, blue: 0.47).opacity(0.15), Color(red: 0.08, green: 0.24, blue: 0.20).opacity(0.30)],
                    playColor: Color(red: 0.47, green: 0.78, blue: 0.63).opacity(0.40)
                )
            }
            .padding(.trailing, 14)
        }
    }

    private func videoCard(title: String, channel: String, duration: String, gradient: [Color], playColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 124)

                // Play icon
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(playColor)

                // Duration badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(duration)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(2)
                .padding(.top, 8)

            Text(channel)
                .font(.system(size: 10))
                .foregroundStyle(subtleText.opacity(0.35))
                .padding(.top, 3)
        }
        .frame(width: 220)
    }

    // MARK: - Vita Sugere

    private var vitaSugereSection: some View {
        VitaGlassCard {
            HStack(alignment: .center, spacing: 12) {
                Image("vita-btn-idle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Vita sugere")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.90))
                    Text("Foque em Opióides — seu acerto está em 42%. Recomendo 20 questões + revisar flashcards antes da P2.")
                        .font(.system(size: 12))
                        .foregroundStyle(subtleText.opacity(0.50))
                        .lineSpacing(2)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(subtleText.opacity(0.35))
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
    }
}
