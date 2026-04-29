import SwiftUI

// MARK: - Session Mode

enum FlashcardFilterMode: String, CaseIterable {
    case all = "all"
    case newOnly = "new"
    case reviewOnly = "review"

    var label: String {
        switch self {
        case .all: return "Todos"
        case .newOnly: return "Apenas novos"
        case .reviewOnly: return "Apenas revisão"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.stack.3d.up.fill"
        case .newOnly: return "sparkles"
        case .reviewOnly: return "arrow.clockwise"
        }
    }
}

// MARK: - Card Sort Order

enum FlashcardSortOrder: String, CaseIterable {
    case random = "random"
    case dueDate = "due"
    case added = "added"

    var label: String {
        switch self {
        case .random: return "Aleatório"
        case .dueDate: return "Por vencimento"
        case .added: return "Ordem de criação"
        }
    }
}

// MARK: - Settings Model

@Observable
final class FlashcardSettings {
    // Session
    var sessionMode: FlashcardFilterMode = .all
    var sortOrder: FlashcardSortOrder = .random

    // Daily limits (Anki defaults: 20 new, 200 review)
    var dailyNewLimit: Int = 20
    var dailyReviewLimit: Int = 200

    // FSRS
    var desiredRetention: Double = 0.90
    var leechThreshold: Int = 8

    // Display
    var showTimer: Bool = true
    var showIntervalPreview: Bool = true
    var autoAdvanceSeconds: Int = 0  // 0 = off

    static let newLimitOptions = [5, 10, 20, 30, 50, 100, 999]
    static let reviewLimitOptions = [50, 100, 150, 200, 300, 500, 999]
    static let retentionOptions = [0.80, 0.85, 0.90, 0.92, 0.95, 0.97]
    static let leechOptions = [4, 6, 8, 10, 15, 999]
    static let autoAdvanceOptions = [0, 5, 10, 15, 30, 60]
}

// MARK: - Settings Screen (pushed route within shell)

struct FlashcardSettingsScreen: View {

    @Environment(Router.self) private var router

    var onBack: () -> Void

    private var vm: FlashcardViewModel? { router.activeFlashcardVM }
    private var settings: FlashcardSettings? { router.activeFlashcardSettings }

    private let accentGold = VitaColors.accent

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let settings {
                settingsContent(settings: settings)
            }
        }
        // No duplicate background — shell provides VitaAmbientBackground
        .navigationBarHidden(true)
        .onDisappear {
            // Apply settings when navigating back to session
            if let vm, let settings {
                vm.applySettings(settings)
            }
        }
    }

    @ViewBuilder
    private func settingsContent(settings: FlashcardSettings) -> some View {
        VStack(alignment: .leading, spacing: 20) {

            // MARK: Card Actions
            if vm?.currentCard != nil {
                sectionHeader("Card atual")

                actionRow(
                    icon: "moon.fill",
                    label: "Enterrar até amanhã",
                    subtitle: "Esconde só hoje",
                    color: VitaColors.accent,
                    action: {
                        vm?.buryCurrentCard()
                        onBack()
                    }
                )

                actionRow(
                    icon: "eye.slash.fill",
                    label: "Suspender card",
                    subtitle: "Não aparece mais",
                    color: .red.opacity(0.8),
                    action: {
                        vm?.suspendCurrentCard()
                        onBack()
                    }
                )
            }

            // MARK: Session Mode
            sectionHeader("Modo da sessão")
            VStack(spacing: 6) {
                ForEach(FlashcardFilterMode.allCases, id: \.self) { mode in
                    modeRow(mode, settings: settings)
                }
            }

            // MARK: Daily Limits
            sectionHeader("Limites diários")

            limitPicker(
                label: "Novos por dia",
                icon: "sparkles",
                value: settings.dailyNewLimit,
                options: FlashcardSettings.newLimitOptions,
                onChange: { settings.dailyNewLimit = $0 }
            )

            limitPicker(
                label: "Revisões por dia",
                icon: "arrow.clockwise",
                value: settings.dailyReviewLimit,
                options: FlashcardSettings.reviewLimitOptions,
                onChange: { settings.dailyReviewLimit = $0 }
            )

            // MARK: Scheduling
            sectionHeader("Agendamento")

            retentionPicker(settings: settings)

            limitPicker(
                label: "Limite de sanguessugas",
                icon: "ant.fill",
                value: settings.leechThreshold,
                options: FlashcardSettings.leechOptions,
                unlimitedLabel: "Desativado",
                onChange: { settings.leechThreshold = $0 }
            )

            // MARK: Order
            sectionHeader("Ordem dos cards")
            VStack(spacing: 6) {
                ForEach(FlashcardSortOrder.allCases, id: \.self) { order in
                    sortRow(order, settings: settings)
                }
            }

            // MARK: Display
            sectionHeader("Exibição")

            toggleRow(
                label: "Mostrar cronômetro",
                icon: "timer",
                isOn: settings.showTimer,
                onToggle: { settings.showTimer = $0 }
            )

            toggleRow(
                label: "Mostrar intervalo nos botões",
                icon: "calendar.badge.clock",
                isOn: settings.showIntervalPreview,
                onToggle: { settings.showIntervalPreview = $0 }
            )

            Spacer().frame(height: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Retention Picker

    private func retentionPicker(settings: FlashcardSettings) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14))
                .foregroundStyle(accentGold.opacity(0.6))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Retenção desejada")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.80))
                Text("Quanto maior, intervalos menores")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.30))
            }
            Spacer()
            Menu {
                ForEach(FlashcardSettings.retentionOptions, id: \.self) { opt in
                    Button("\(Int(opt * 100))%") {
                        settings.desiredRetention = opt
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(Int(settings.desiredRetention * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundStyle(accentGold.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accentGold.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(settingRowBg)
        .overlay(settingRowBorder)
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(1.0)
            .foregroundStyle(accentGold.opacity(0.50))
            .padding(.top, 4)
    }

    private func actionRow(icon: String, label: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(color)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.30))
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func modeRow(_ mode: FlashcardFilterMode, settings: FlashcardSettings) -> some View {
        let isSelected = settings.sessionMode == mode
        return Button(action: { settings.sessionMode = mode }) {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? accentGold : .white.opacity(0.4))
                    .frame(width: 28)
                Text(mode.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.95) : .white.opacity(0.55))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accentGold)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accentGold.opacity(0.08) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? accentGold.opacity(0.20) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func sortRow(_ order: FlashcardSortOrder, settings: FlashcardSettings) -> some View {
        let isSelected = settings.sortOrder == order
        return Button(action: { settings.sortOrder = order }) {
            HStack(spacing: 12) {
                Text(order.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.95) : .white.opacity(0.55))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accentGold)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accentGold.opacity(0.08) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? accentGold.opacity(0.20) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func limitPicker(label: String, icon: String, value: Int, options: [Int], unlimitedLabel: String = "Sem limite", onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(accentGold.opacity(0.6))
                .frame(width: 28)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.80))
            Spacer()
            Menu {
                ForEach(options, id: \.self) { opt in
                    Button(opt >= 999 ? unlimitedLabel : "\(opt)") {
                        onChange(opt)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(value >= 999 ? "∞" : "\(value)")
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundStyle(accentGold.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accentGold.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(settingRowBg)
        .overlay(settingRowBorder)
    }

    private func toggleRow(label: String, icon: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(accentGold.opacity(0.6))
                .frame(width: 28)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.80))
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: { onToggle($0) }))
                .tint(accentGold)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(settingRowBg)
        .overlay(settingRowBorder)
    }

    private var settingRowBg: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.03))
    }

    private var settingRowBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
    }
}
