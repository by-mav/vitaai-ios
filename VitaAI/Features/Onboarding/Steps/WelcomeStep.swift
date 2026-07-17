import SwiftUI

// MARK: - Welcome Step — University Selection

struct WelcomeStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @Binding var showManualEntry: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onComplete: () -> Void

    private let semesterColumns = Array(
        repeating: GridItem(.flexible(), spacing: VitaTokens.Spacing.sm),
        count: 6
    )

    var body: some View {
        Group {
            if let selected = viewModel.selectedUniversity {
                semesterSelection(for: selected)
                    .transition(.opacity)
            } else {
                FaculdadePickerSheet(
                    initialUniversities: viewModel.allUniversities,
                    presentation: .onboardingInline,
                    onLoaded: { universities in
                        viewModel.allUniversities = universities
                    },
                    onSelect: { university in
                        viewModel.selectUniversity(university)
                    },
                    onAddCustom: {
                        showManualEntry = true
                    }
                )
                .transition(.opacity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: viewModel.selectedUniversity?.id
        )
    }

    private func semesterSelection(for university: University) -> some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: "building.columns")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: VitaTokens.Spacing._2xl)

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

                    Text(universityLocation(university))
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "checkmark.circle.fill")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.accent)
            }
            .padding(.vertical, VitaTokens.Spacing.md)

            Divider()
                .overlay(VitaColors.glassBorder)

            Text(String(localized: "onboarding_semester_question"))
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .padding(.top, VitaTokens.Spacing.md)

            LazyVGrid(columns: semesterColumns, spacing: VitaTokens.Spacing.sm) {
                ForEach(1...12, id: \.self) { semester in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.selectSemester(semester)
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + (reduceMotion ? 0 : 0.12)
                        ) {
                            onComplete()
                        }
                    } label: {
                        Text("\(semester)º")
                            .font(
                                viewModel.selectedSemester == semester
                                    ? VitaTypography.labelLarge
                                    : VitaTypography.labelMedium
                            )
                            .foregroundStyle(
                                viewModel.selectedSemester == semester
                                    ? VitaColors.accentLight
                                    : VitaColors.textSecondary
                            )
                            .frame(maxWidth: .infinity)
                            .frame(
                                minHeight: VitaTokens.Spacing._3xl + VitaTokens.Spacing.md
                            )
                            .background {
                                RoundedRectangle(
                                    cornerRadius: VitaTokens.Radius.md,
                                    style: .continuous
                                )
                                .fill(
                                    viewModel.selectedSemester == semester
                                        ? VitaColors.accent.opacity(0.16)
                                        : VitaColors.glassBg
                                )
                            }
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: VitaTokens.Radius.md,
                                    style: .continuous
                                )
                                .stroke(
                                    viewModel.selectedSemester == semester
                                        ? VitaColors.accent.opacity(0.42)
                                        : VitaColors.glassBorder,
                                    lineWidth: 1
                                )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboardingSemester_\(semester)")
                    .accessibilityLabel(
                        String(
                            format: String(localized: "onboarding_semester_accessibility"),
                            semester
                        )
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func universityLocation(_ university: University) -> String {
        var components: [String] = []
        if !university.city.isEmpty { components.append(university.city) }
        if university.countryCode == "BR", !university.state.isEmpty {
            components.append(university.state)
        } else {
            components.append(university.localizedCountryName)
        }
        return components.joined(separator: " · ")
    }
}

// MARK: - Manual University Entry Sheet

struct ManualUniversitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = ""
    @State private var state = ""
    var onSubmit: (String, String, String) -> Void

    var body: some View {
        VitaSheet(detents: [.medium]) {
        NavigationStack {
            VStack(spacing: 16) {
                Text(String(localized: "onboarding_add_uni_title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 20)

                Text(String(localized: "onboarding_add_uni_subtitle"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)

                VStack(spacing: VitaTokens.Spacing.md) {
                    OnboardingTextInput(
                        value: $name,
                        placeholder: String(localized: "onboarding_add_uni_name_placeholder"),
                        leadingSystemImage: "building.columns",
                        autocapitalization: .words
                    )
                    OnboardingTextInput(
                        value: $city,
                        placeholder: String(localized: "onboarding_add_uni_city_placeholder"),
                        leadingSystemImage: "mappin.and.ellipse",
                        autocapitalization: .words
                    )
                    OnboardingTextInput(
                        value: $state,
                        placeholder: String(localized: "onboarding_add_uni_state_placeholder"),
                        leadingSystemImage: "map",
                        autocapitalization: .characters
                    )
                }
                .padding(.horizontal, 20)

                VitaButton(
                    text: String(localized: "onboarding_add_uni_submit"),
                    action: {
                        guard !name.isEmpty else { return }
                        onSubmit(name, city, state)
                        dismiss()
                    },
                    variant: .primary,
                    size: .md,
                    isEnabled: !name.isEmpty,
                    fillsWidth: true
                )
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(VitaColors.surface.ignoresSafeArea())
        }
        }
    }

}
