import SwiftUI
import UIKit

private enum UniversitySortMode: String, CaseIterable, Identifiable {
    case alphabetical
    case enade

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alphabetical:
            return String(localized: "university_picker_sort_az")
        case .enade:
            return String(localized: "university_picker_sort_enade")
        }
    }
}

// MARK: - FaculdadePickerSheet

/// Canonical university catalog used both by Faculdade and onboarding.
/// The default mode saves directly to the profile; onboarding injects an
/// `onSelect` closure so the same list writes to its durable draft instead.
struct FaculdadePickerSheet: View {
    @Environment(\.appData) private var appData
    @Environment(\.dismiss) private var dismiss

    private let initialUniversities: [University]
    private let onLoaded: (([University]) -> Void)?
    private let onSelect: ((University) -> Void)?
    private let onAddCustom: (() -> Void)?

    @State private var query = ""
    @State private var all: [University] = []
    @State private var sortMode: UniversitySortMode = .enade
    @State private var loading = true
    @State private var savingId: String?

    private static let bundledUniversities: [University] = {
        guard let data = NSDataAsset(name: "UniversitiesFallback")?.data else {
            return []
        }
        return (try? JSONDecoder().decode([University].self, from: data)) ?? []
    }()

    init(
        initialUniversities: [University] = [],
        onLoaded: (([University]) -> Void)? = nil,
        onSelect: ((University) -> Void)? = nil,
        onAddCustom: (() -> Void)? = nil
    ) {
        let localCatalog = Self.curatedCatalog(
            initialUniversities.isEmpty
                ? Self.bundledUniversities
                : initialUniversities
        )
        self.initialUniversities = initialUniversities
        self.onLoaded = onLoaded
        self.onSelect = onSelect
        self.onAddCustom = onAddCustom
        _all = State(initialValue: localCatalog)
        _loading = State(initialValue: localCatalog.isEmpty)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedQuery: String {
        trimmedQuery.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )
    }

    private var visibleUniversities: [University] {
        let candidates: [University]
        if normalizedQuery.isEmpty {
            candidates = all
        } else {
            candidates = all.filter { university in
                "\(university.name) \(university.shortName) \(university.city) \(university.state)"
                    .folding(
                        options: [.diacriticInsensitive, .caseInsensitive],
                        locale: .current
                    )
                    .contains(normalizedQuery)
            }
        }

        return candidates.sorted(by: comesBefore)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
            header

            VitaInput(
                value: $query,
                placeholder: String(localized: "university_picker_search"),
                leadingSystemImage: "magnifyingglass",
                showClearButton: true,
                submitLabel: .search
            )
            .accessibilityIdentifier("universityPickerSearch")

            sortControl

            catalog
        }
        .padding(.horizontal, VitaTokens.Spacing._2xl)
        .padding(.top, VitaTokens.Spacing._2xl)
        .background(VitaColors.surface.ignoresSafeArea())
        .task { await loadCatalog() }
    }

    private var header: some View {
        HStack(spacing: VitaTokens.Spacing.md) {
            Text(String(localized: "university_picker_title"))
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.textPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(
                        width: VitaTokens.Spacing._3xl + VitaTokens.Spacing.md,
                        height: VitaTokens.Spacing._3xl + VitaTokens.Spacing.md
                    )
                    .background(Circle().fill(VitaColors.glassBg))
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "onboarding_close"))
        }
    }

    private var sortControl: some View {
        HStack(spacing: VitaTokens.Spacing.xxs) {
            ForEach(UniversitySortMode.allCases) { mode in
                let isSelected = sortMode == mode

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        sortMode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(
                            isSelected
                                ? VitaTypography.labelLarge
                                : VitaTypography.labelMedium
                        )
                        .foregroundStyle(
                            isSelected
                                ? VitaColors.accentLight
                                : VitaColors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .frame(
                            minHeight: VitaTokens.Spacing._3xl + VitaTokens.Spacing.sm
                        )
                        .background {
                            RoundedRectangle(
                                cornerRadius: VitaTokens.Radius.md,
                                style: .continuous
                            )
                            .fill(
                                isSelected
                                    ? VitaColors.accent.opacity(0.16)
                                    : Color.clear
                            )
                        }
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: VitaTokens.Radius.md,
                                style: .continuous
                            )
                            .stroke(
                                isSelected
                                    ? VitaColors.accent.opacity(0.34)
                                    : Color.clear,
                                lineWidth: 1
                            )
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(VitaTokens.Spacing.xxs)
        .background {
            RoundedRectangle(
                cornerRadius: VitaTokens.Radius.lg,
                style: .continuous
            )
            .fill(VitaColors.glassBg)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: VitaTokens.Radius.lg,
                style: .continuous
            )
            .stroke(VitaColors.glassBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "university_picker_sort_accessibility"))
        .accessibilityIdentifier("universityPickerSort")
    }

    @ViewBuilder
    private var catalog: some View {
        if loading {
            ProgressView()
                .tint(VitaColors.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if all.isEmpty {
            loadFailure
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(visibleUniversities) { university in
                        row(university)

                        if university.id != visibleUniversities.last?.id {
                            Divider()
                                .overlay(VitaColors.glassBorder)
                        }
                    }

                    if visibleUniversities.isEmpty {
                        if trimmedQuery.count >= 2 {
                            notFoundCard
                        } else {
                            Text(String(localized: "university_picker_empty"))
                                .font(VitaTypography.bodySmall)
                                .foregroundStyle(VitaColors.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, VitaTokens.Spacing._3xl)
                        }
                    }
                }
                .padding(.bottom, VitaTokens.Spacing._3xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func row(_ university: University) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            if let onSelect {
                onSelect(university)
                dismiss()
                return
            }

            savingId = university.id
            Task {
                await appData.selectUniversity(university)
                dismiss()
            }
        } label: {
            HStack(spacing: VitaTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                    HStack(spacing: VitaTokens.Spacing.sm) {
                        Text(university.displayName)
                            .font(VitaTypography.titleSmall)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)

                        if let score = university.enameConcept, score > 0 {
                            ENAMEDBadge(score: score)
                        }
                    }

                    Text("\(university.city) · \(university.state)")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if savingId == university.id {
                    ProgressView().tint(VitaColors.accent)
                } else {
                    Image(systemName: "chevron.right")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .frame(
                minHeight: VitaTokens.Spacing._4xl + VitaTokens.Spacing.xs,
                alignment: .center
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var loadFailure: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            Image(systemName: "arrow.clockwise")
                .font(VitaTypography.headlineMedium)
                .foregroundStyle(VitaColors.accent)

            Text(String(localized: "university_picker_load_error"))
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await loadCatalog(forceRemote: true) }
            } label: {
                Text(String(localized: "university_picker_retry"))
                    .font(VitaTypography.buttonMedium)
                    .foregroundStyle(VitaColors.accentLight)
                    .frame(
                        minHeight: VitaTokens.Spacing._3xl + VitaTokens.Spacing.md
                    )
                    .padding(.horizontal, VitaTokens.Spacing._2xl)
                    .background(
                        Capsule().fill(VitaColors.accent.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, VitaTokens.Spacing._3xl)
    }

    private var notFoundCard: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            Text(String(localized: "onboarding_uni_not_found"))
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary)

            Text(String(localized: "university_picker_custom_body"))
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if let onAddCustom {
                    dismiss()
                    DispatchQueue.main.async { onAddCustom() }
                    return
                }

                savingId = "__custom__"
                Task {
                    await appData.addCustomFaculty(name: trimmedQuery)
                    dismiss()
                }
            } label: {
                HStack(spacing: VitaTokens.Spacing.sm) {
                    if savingId == "__custom__" {
                        ProgressView().tint(VitaColors.surface)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }

                    Text(
                        String(localized: "university_picker_add_custom")
                            .replacingOccurrences(of: "%@", with: trimmedQuery)
                    )
                    .font(VitaTypography.labelMedium)
                    .lineLimit(1)
                }
                .foregroundStyle(VitaColors.surface)
                .frame(maxWidth: .infinity)
                .frame(
                    minHeight: VitaTokens.Spacing._3xl + VitaTokens.Spacing.md
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: VitaTokens.Radius.md,
                        style: .continuous
                    )
                    .fill(VitaColors.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(savingId == "__custom__")
        }
        .padding(VitaTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(
                cornerRadius: VitaTokens.Radius.lg,
                style: .continuous
            )
            .fill(VitaColors.glassBg)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: VitaTokens.Radius.lg,
                style: .continuous
            )
            .stroke(VitaColors.glassBorder, lineWidth: 1)
        }
        .padding(.top, VitaTokens.Spacing.lg)
    }

    private func comesBefore(_ lhs: University, _ rhs: University) -> Bool {
        let alphabetical = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)

        switch sortMode {
        case .alphabetical:
            return alphabetical == .orderedAscending
        case .enade:
            let lhsScore = lhs.enameConcept ?? Int.min
            let rhsScore = rhs.enameConcept ?? Int.min
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            return alphabetical == .orderedAscending
        }
    }

    private func loadCatalog(forceRemote: Bool = false) async {
        if !forceRemote, !all.isEmpty {
            onLoaded?(all)
        }

        if forceRemote {
            loading = all.isEmpty
        }

        let remote = await appData.loadUniversities("")
        if !remote.isEmpty {
            let curatedRemote = Self.curatedCatalog(remote)
            all = curatedRemote
            onLoaded?(curatedRemote)
        }

        loading = false
    }

    private static func curatedCatalog(_ universities: [University]) -> [University] {
        var curated = universities.compactMap { university -> University? in
            let identity = "\(university.name) \(university.shortName) \(university.city)"
                .folding(
                    options: [.diacriticInsensitive, .caseInsensitive],
                    locale: .current
                )

            if identity.contains("ulbra") && identity.contains("torres") {
                return nil
            }

            let concept: Int?
            if identity.contains("ulbra") {
                concept = identity.contains("canoas") ? 2 : nil
            } else if identity.contains("cesuca") {
                concept = nil
            } else {
                concept = university.enameConcept
            }

            return University(
                id: university.id,
                name: university.name,
                shortName: university.shortName,
                city: university.city,
                state: university.state,
                enameConcept: concept,
                portals: university.portals
            )
        }

        let hasCesuca = curated.contains { university in
            "\(university.name) \(university.shortName)"
                .folding(
                    options: [.diacriticInsensitive, .caseInsensitive],
                    locale: .current
                )
                .contains("cesuca")
        }
        if !hasCesuca {
            curated.append(
                University(
                    id: "local-cesuca-cachoeirinha",
                    name: "Centro Universitário CESUCA",
                    shortName: "CESUCA",
                    city: "Cachoeirinha",
                    state: "RS",
                    enameConcept: nil,
                    portals: []
                )
            )
        }

        return curated
    }
}
