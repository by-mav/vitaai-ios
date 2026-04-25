import SwiftUI

// MARK: - ProfessorProfileSheet
//
// Sheet presented when the user taps the professor name in DisciplineDetailScreen.
// Data source: GET /api/subjects/{subjectId}/professor-profile
// Layout: header → stats row → style bars → topic pills → tendencies → CTA

struct ProfessorProfileSheet: View {
    let subjectId: String

    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var vm: ProfessorProfileViewModel?
    @State private var showUploadSheet = false

    // Tokens
    private var goldPrimary: Color { VitaColors.accentHover }
    private var goldMuted: Color { VitaColors.accentLight }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.06) }

    var body: some View {
        VitaSheet {
            ScrollView(showsIndicators: false) {
                if let vm {
                    if vm.isLoading {
                        ProgressView()
                            .tint(VitaColors.accent)
                            .padding(.top, 80)
                    } else if let error = vm.error {
                        errorView(message: error, vm: vm)
                    } else if vm.hasProfile, let profile = vm.profile {
                        profileContent(vm: vm, profile: profile)
                    } else if let profile = vm.profile {
                        emptyStateView(professorName: profile.name, vm: vm)
                    } else {
                        emptyStateView(professorName: "Professor", vm: vm)
                    }
                } else {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .padding(.top, 80)
                }
            }
        }
        .onAppear {
            if vm == nil {
                vm = ProfessorProfileViewModel(subjectId: subjectId, api: container.api)
                Task { @MainActor in await vm?.load() }
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            VitaSheet(title: "Enviar Prova") {
                if let vm {
                    ExamUploadSheet(subjectId: subjectId) {
                        Task { @MainActor in await vm.refresh() }
                    }
                }
            }
        }
    }

    // MARK: - Profile Content

    private func profileContent(vm: ProfessorProfileViewModel, profile: ProfessorProfileResponse) -> some View {
        VStack(spacing: 16) {
            // Handle bar indicator space
            Color.clear.frame(height: 4)

            // Header
            headerView(profile: profile)

            // Stats row
            statsRow(vm: vm, profile: profile)
                .padding(.horizontal, 16)

            // Style distribution bars
            if let dist = profile.profileData?.styleDistribution, !dist.isEmpty {
                styleDistributionCard(dist: dist)
                    .padding(.horizontal, 16)
            }

            // Focus topics
            if let topics = profile.profileData?.topFocusTopics, !topics.isEmpty {
                topicsCard(topics: topics)
                    .padding(.horizontal, 16)
            }

            // Tendencies
            if let text = profile.profileData?.tendencies, !text.isEmpty {
                tendenciesCard(text: text)
                    .padding(.horizontal, 16)
            }

            // CTA
            ctaButton(vm: vm)
                .padding(.horizontal, 16)

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Header

    private func headerView(profile: ProfessorProfileResponse) -> some View {
        VStack(spacing: 4) {
            Text(profile.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let uni = profile.university, !uni.isEmpty {
                Text(uni)
                    .font(.system(size: 12))
                    .foregroundStyle(textDim)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Stats Row (3 boxes)

    private func statsRow(vm: ProfessorProfileViewModel, profile: ProfessorProfileResponse) -> some View {
        HStack(spacing: 10) {
            statBox(
                value: "\(profile.examCount)",
                label: "Provas",
                valueColor: goldPrimary
            )

            statBox(
                value: vm.difficultyLabel,
                label: "Dificuldade",
                valueColor: difficultyColor(vm.difficultyColor)
            )

            statBox(
                value: "\(vm.reasoningPercent)%",
                label: "Raciocínio",
                valueColor: VitaColors.accent
            )
        }
    }

    private func statBox(value: String, label: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(glassBorder, lineWidth: 0.5)
        )
    }

    private func difficultyColor(_ d: ProfessorProfileViewModel.DifficultyColor) -> Color {
        switch d {
        case .easy: return VitaColors.dataGreen
        case .medium: return VitaColors.dataAmber
        case .hard: return VitaColors.dataRed
        }
    }

    // MARK: - Style Distribution Bars

    private func styleDistributionCard(dist: [String: Double]) -> some View {
        let sorted = dist.sorted { $0.value > $1.value }
        let maxVal = sorted.first?.value ?? 1.0

        return VitaGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(goldPrimary.opacity(0.80))
                    Text("Estilos de Questão")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                }

                ForEach(Array(sorted.enumerated()), id: \.element.key) { idx, item in
                    styleBar(label: item.key, value: item.value, maxValue: maxVal, rank: idx)
                }
            }
            .padding(16)
        }
    }

    private func styleBar(label: String, value: Double, maxValue: Double, rank: Int) -> some View {
        let barColor = barColorForRank(rank)
        let pct = maxValue > 0 ? value / maxValue : 0
        let displayPct = Int(value * 100)

        return HStack(spacing: 10) {
            Text(label.replacingOccurrences(of: "-", with: " ").capitalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textWarm.opacity(0.75))
                .frame(width: 110, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor.opacity(0.12))
                        .frame(maxWidth: .infinity)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 6)

            Text("\(displayPct)%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(barColor)
                .frame(width: 34, alignment: .trailing)
        }
        .frame(height: 20)
    }

    private func barColorForRank(_ rank: Int) -> Color {
        switch rank {
        case 0: return VitaColors.accentHover
        case 1: return VitaColors.accent
        case 2: return VitaColors.accentLight
        default: return VitaColors.accentLight.opacity(0.6)
        }
    }

    // MARK: - Focus Topics

    private func topicsCard(topics: [String]) -> some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(goldPrimary.opacity(0.80))
                    Text("Tópicos Frequentes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                }

                FlowLayout(spacing: 6) {
                    ForEach(topics, id: \.self) { topic in
                        Text(topic)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(goldPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(goldPrimary.opacity(0.10))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(goldPrimary.opacity(0.20), lineWidth: 0.5)
                            )
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Tendencies

    private func tendenciesCard(text: String) -> some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(goldPrimary.opacity(0.80))
                    Text("Tendências")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                }

                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(textWarm.opacity(0.70))
                    .lineSpacing(3)
            }
            .padding(16)
        }
    }

    // MARK: - CTA Button

    private func ctaButton(vm: ProfessorProfileViewModel) -> some View {
        Button {
            showUploadSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.viewfinder.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Analisar Prova")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(VitaColors.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(goldPrimary)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private func emptyStateView(professorName: String, vm: ProfessorProfileViewModel) -> some View {
        VStack(spacing: 24) {
            Color.clear.frame(height: 4)

            // Header even in empty state
            VStack(spacing: 4) {
                Text(professorName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            Spacer().frame(height: 16)

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(goldPrimary.opacity(0.35))

            VStack(spacing: 6) {
                Text("Nenhuma prova analisada ainda")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text("Envie uma prova anterior para descobrir o estilo deste professor")
                    .font(.system(size: 13))
                    .foregroundStyle(textDim)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            ctaButton(vm: vm)
                .padding(.horizontal, 16)

            Spacer().frame(height: 32)
        }
    }

    // MARK: - Error View

    private func errorView(message: String, vm: ProfessorProfileViewModel) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(VitaColors.dataAmber)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(textWarm)
                .multilineTextAlignment(.center)
            Button("Tentar novamente") {
                Task { @MainActor in await vm.refresh() }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(goldPrimary)
        }
        .padding(.horizontal, 32)
    }
}

