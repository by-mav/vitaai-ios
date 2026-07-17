import SwiftUI
import UIKit

enum FaculdadePickerPresentation {
    case sheet
    case onboardingInline
}

// MARK: - FaculdadePickerSheet

/// Canonical global medical-school catalog used by Faculdade and onboarding.
/// Results are fetched by country in small pages; thousands of schools are
/// never materialized in memory or rendered at once.
struct FaculdadePickerSheet: View {
    @Environment(\.appData) private var appData
    @Environment(\.dismiss) private var dismiss

    private static let pageSize = 30

    private let presentation: FaculdadePickerPresentation
    private let onLoaded: (([University]) -> Void)?
    private let onSelect: ((University) -> Void)?
    private let onAddCustom: (() -> Void)?

    @State private var query = ""
    @State private var countryQuery = ""
    @State private var all: [University]
    @State private var countries: [UniversityCountry] = []
    @State private var selectedCountryCode: String
    @State private var choosingCountry = false
    @State private var loading = true
    @State private var loadingMore = false
    @State private var loadFailed = false
    @State private var hasMore = false
    @State private var total = 0
    @State private var savingId: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private static let bundledUniversities: [University] = {
        guard let data = NSDataAsset(name: "UniversitiesFallback")?.data else {
            return []
        }
        return (try? JSONDecoder().decode([University].self, from: data)) ?? []
    }()

    private static var deviceCountryCode: String {
        let code = Locale.autoupdatingCurrent.region?.identifier.uppercased() ?? "BR"
        return code.count == 2 ? code : "BR"
    }

    init(
        initialUniversities: [University] = [],
        presentation: FaculdadePickerPresentation = .sheet,
        onLoaded: (([University]) -> Void)? = nil,
        onSelect: ((University) -> Void)? = nil,
        onAddCustom: (() -> Void)? = nil
    ) {
        let countryCode = Self.deviceCountryCode
        let localCatalog = countryCode == "BR"
            ? Self.curatedCatalog(
                initialUniversities.isEmpty
                    ? Self.bundledUniversities
                    : initialUniversities,
                countryCode: countryCode
            )
            : []

        self.presentation = presentation
        self.onLoaded = onLoaded
        self.onSelect = onSelect
        self.onAddCustom = onAddCustom
        _selectedCountryCode = State(initialValue: countryCode)
        _all = State(initialValue: localCatalog)
        _loading = State(initialValue: localCatalog.isEmpty)
        _total = State(initialValue: localCatalog.count)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedCountryName: String {
        countries.first(where: { $0.code == selectedCountryCode })?.localizedName
            ?? Locale.autoupdatingCurrent.localizedString(forRegionCode: selectedCountryCode)
            ?? selectedCountryCode
    }

    private var filteredCountries: [UniversityCountry] {
        let normalized = countryQuery.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )
        let source = normalized.isEmpty
            ? countries
            : countries.filter { country in
                "\(country.localizedName) \(country.name) \(country.code)"
                    .folding(
                        options: [.diacriticInsensitive, .caseInsensitive],
                        locale: .current
                    )
                    .contains(normalized)
            }
        return source.sorted {
            $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.lg) {
            if presentation == .sheet {
                header
            }

            searchControl

            Group {
                if choosingCountry {
                    countryCatalog
                } else {
                    catalog
                }
            }
            .transition(.opacity)
        }
        .padding(
            .horizontal,
            presentation == .sheet ? VitaTokens.Spacing._2xl : 0
        )
        .padding(
            .top,
            presentation == .sheet ? VitaTokens.Spacing._2xl : 0
        )
        .background {
            if presentation == .sheet {
                VitaColors.surface.ignoresSafeArea()
            }
        }
        .task { await bootstrap() }
        .onChange(of: query) { _, _ in scheduleSearch() }
        .onDisappear { searchTask?.cancel() }
        .animation(.easeInOut(duration: 0.18), value: choosingCountry)
    }

    private var header: some View {
        HStack(spacing: VitaTokens.Spacing.md) {
            Text(String(localized: "university_picker_title"))
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.textPrimary)

            Spacer()

            Button { dismiss() } label: {
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

    private var activeSearchText: Binding<String> {
        Binding(
            get: { choosingCountry ? countryQuery : query },
            set: { value in
                if choosingCountry {
                    countryQuery = value
                } else {
                    query = value
                }
            }
        )
    }

    private var searchControl: some View {
        HStack(spacing: VitaTokens.Spacing.sm) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                choosingCountry.toggle()
                countryQuery = ""
                searchFocused = false
            } label: {
                Text(flagEmoji(for: selectedCountryCode))
                    .font(VitaTypography.titleMedium)
                    .frame(
                        width: VitaTokens.Spacing._4xl + VitaTokens.Spacing.md,
                        height: VitaTokens.Spacing._4xl + VitaTokens.Spacing.md
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("universityCountrySelector")
            .accessibilityLabel(String(localized: "university_picker_country_label"))
            .accessibilityValue(selectedCountryName)

            Image(systemName: "magnifyingglass")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .frame(width: VitaTokens.Spacing._2xl)

            TextField(
                choosingCountry
                    ? String(localized: "university_picker_country_search")
                    : String(localized: "university_picker_search_global"),
                text: activeSearchText
            )
            .font(VitaTypography.bodyLarge)
            .foregroundStyle(VitaColors.textPrimary)
            .tint(VitaColors.accent)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($searchFocused)
            .accessibilityIdentifier(
                choosingCountry ? "universityCountrySearch" : "universityPickerSearch"
            )

            if !activeSearchText.wrappedValue.isEmpty {
                Button { activeSearchText.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(
                            width: VitaTokens.Spacing._4xl + VitaTokens.Spacing.md,
                            height: VitaTokens.Spacing._4xl + VitaTokens.Spacing.md
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "common_clear"))
            }
        }
        .padding(.leading, VitaTokens.Spacing.xs)
        .padding(.trailing, VitaTokens.Spacing.xs)
        .frame(minHeight: VitaTokens.Spacing._4xl + VitaTokens.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .fill(VitaColors.glassBg)
        }
        .overlay {
            RoundedRectangle(cornerRadius: VitaTokens.Radius.md, style: .continuous)
                .stroke(
                    searchFocused ? VitaColors.accent : VitaColors.glassBorder,
                    lineWidth: 1
                )
        }
        .animation(.easeInOut(duration: 0.15), value: searchFocused)
    }

    private var countryCatalog: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(filteredCountries) { country in
                    Button { selectCountry(country) } label: {
                        HStack(spacing: VitaTokens.Spacing.md) {
                            Text(flagEmoji(for: country.code))
                                .font(VitaTypography.titleMedium)

                            Text(country.localizedName)
                                .font(VitaTypography.titleSmall)
                                .foregroundStyle(VitaColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(country.schoolCount)")
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)

                            if country.code == selectedCountryCode {
                                Image(systemName: "checkmark")
                                    .font(VitaTypography.labelMedium)
                                    .foregroundStyle(VitaColors.accent)
                            }
                        }
                        .padding(.horizontal, VitaTokens.Spacing.sm)
                        .frame(minHeight: VitaTokens.Spacing._4xl + VitaTokens.Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("universityCountry_\(country.code)")

                    if country.id != filteredCountries.last?.id {
                        Divider().overlay(VitaColors.glassBorder)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var catalog: some View {
        if all.isEmpty, loading {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: VitaTokens.Spacing._4xl * 4)
                .accessibilityLabel(String(localized: "university_picker_loading"))
        } else if all.isEmpty, loadFailed {
            loadFailure
        } else if all.isEmpty {
            emptyCatalog
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(all) { university in
                        row(university)
                            .task {
                                if university.id == all.last?.id {
                                    await loadMoreIfNeeded()
                                }
                            }

                        if university.id != all.last?.id {
                            Divider().overlay(VitaColors.glassBorder)
                        }
                    }

                    if loadingMore {
                        ProgressView()
                            .tint(VitaColors.accent)
                            .padding(.vertical, VitaTokens.Spacing.lg)
                    }
                }
                .padding(.bottom, VitaTokens.Spacing._3xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    @ViewBuilder
    private var emptyCatalog: some View {
        if trimmedQuery.count >= 2 {
            notFoundCard
        } else {
            Text(String(localized: "university_picker_empty_country"))
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, VitaTokens.Spacing._3xl)
        }
    }

    private func row(_ university: University) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            if let onSelect {
                onSelect(university)
                if presentation == .sheet { dismiss() }
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

                        if university.countryCode == "BR",
                           let score = university.enameConcept,
                           score > 0 {
                            ENAMEDBadge(score: score)
                        }
                    }

                    Text(locationText(for: university))
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if savingId == university.id {
                    ProgressView().tint(VitaColors.accent)
                } else {
                    Image(systemName: "chevron.right")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(
                .horizontal,
                presentation == .onboardingInline ? VitaTokens.Spacing.sm : 0
            )
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

            Button { scheduleSearch(immediate: true) } label: {
                Text(String(localized: "university_picker_retry"))
                    .font(VitaTypography.buttonMedium)
                    .foregroundStyle(VitaColors.accentLight)
                    .frame(minHeight: VitaTokens.Spacing._3xl + VitaTokens.Spacing.md)
                    .padding(.horizontal, VitaTokens.Spacing._2xl)
                    .background(Capsule().fill(VitaColors.accent.opacity(0.14)))
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

            Button { addCustomUniversity() } label: {
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
                .frame(minHeight: VitaTokens.Spacing._3xl + VitaTokens.Spacing.md)
                .background {
                    RoundedRectangle(
                        cornerRadius: VitaTokens.Radius.md,
                        style: .continuous
                    )
                    .fill(VitaColors.accent)
                }
            }
            .buttonStyle(.plain)
            .disabled(savingId == "__custom__")
        }
        .padding(VitaTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                .fill(VitaColors.glassBg)
        }
        .overlay {
            RoundedRectangle(cornerRadius: VitaTokens.Radius.lg, style: .continuous)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        }
        .padding(.top, VitaTokens.Spacing.lg)
    }

    private func locationText(for university: University) -> String {
        var components: [String] = []
        if !university.city.isEmpty { components.append(university.city) }
        if university.countryCode == "BR", !university.state.isEmpty {
            components.append(university.state)
        } else {
            components.append(university.localizedCountryName)
        }
        return components.joined(separator: " · ")
    }

    private func flagEmoji(for countryCode: String) -> String {
        countryCode
            .uppercased()
            .unicodeScalars
            .compactMap { UnicodeScalar(127_397 + $0.value) }
            .map(String.init)
            .joined()
    }

    private func selectCountry(_ country: UniversityCountry) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedCountryCode = country.code
        choosingCountry = false
        countryQuery = ""
        query = ""
        all = country.code == "BR"
            ? Self.curatedCatalog(Self.bundledUniversities, countryCode: "BR")
            : []
        total = all.count
        hasMore = false
        scheduleSearch(immediate: true)
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(280))
            }
            guard !Task.isCancelled else { return }
            await loadCatalog(reset: true)
        }
    }

    private func bootstrap() async {
        let remoteCountries = await appData.loadUniversityCountries()
        if !remoteCountries.isEmpty {
            countries = remoteCountries
            if !remoteCountries.contains(where: { $0.code == selectedCountryCode }) {
                selectedCountryCode = remoteCountries.contains(where: { $0.code == "BR" })
                    ? "BR"
                    : (remoteCountries.first?.code ?? "BR")
            }
        }
        await loadCatalog(reset: true)
    }

    private func loadCatalog(reset: Bool) async {
        if reset {
            loading = all.isEmpty
            loadFailed = false
            hasMore = false
        }

        let response = await appData.loadUniversitiesPage(
            query: trimmedQuery,
            countryCode: selectedCountryCode,
            limit: Self.pageSize,
            offset: reset ? 0 : all.count
        )

        guard !Task.isCancelled else { return }
        guard let response else {
            loading = false
            loadFailed = all.isEmpty
            return
        }

        let curated = Self.curatedCatalog(
            response.universities,
            countryCode: selectedCountryCode
        )
        if reset {
            all = curated
        } else {
            let existingIds = Set(all.map(\.id))
            all.append(contentsOf: curated.filter { !existingIds.contains($0.id) })
        }
        total = response.total
        hasMore = response.hasMore
        loading = false
        loadFailed = false
        onLoaded?(all)
    }

    private func loadMoreIfNeeded() async {
        guard hasMore, !loadingMore, !loading else { return }
        loadingMore = true
        await loadCatalog(reset: false)
        loadingMore = false
    }

    private func addCustomUniversity() {
        if let onAddCustom {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
            if presentation == .sheet { dismiss() }
            DispatchQueue.main.async { onAddCustom() }
            return
        }

        savingId = "__custom__"
        Task {
            await appData.addCustomFaculty(name: trimmedQuery)
            dismiss()
        }
    }

    private static func curatedCatalog(
        _ universities: [University],
        countryCode: String
    ) -> [University] {
        guard countryCode == "BR" else { return universities }

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
                countryCode: university.countryCode,
                countryName: university.countryName,
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
                    state: "RS"
                )
            )
        }

        return curated
    }
}
