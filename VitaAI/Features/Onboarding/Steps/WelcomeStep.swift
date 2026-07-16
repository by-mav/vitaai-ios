import SwiftUI

// MARK: - Welcome Step — University Selection

struct WelcomeStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @Binding var showManualEntry: Bool
    @State private var showUniversityPicker = false

    private let semesterColumns = Array(
        repeating: GridItem(.flexible(), spacing: VitaTokens.Spacing.sm),
        count: 6
    )

    var body: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.md) {
            if viewModel.selectedUniversity != nil {
                semesterPicker
            }

            universitySelector
        }
        .sheet(isPresented: $showUniversityPicker) {
            VitaSheet(detents: [.large]) {
                FaculdadePickerSheet(
                    initialUniversities: viewModel.allUniversities,
                    onLoaded: { universities in
                        viewModel.allUniversities = universities
                    },
                    onSelect: { university in
                        viewModel.selectUniversity(university)
                    },
                    onAddCustom: {
                        showUniversityPicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showManualEntry = true
                        }
                    }
                )
            }
        }
    }

    private var universitySelector: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showUniversityPicker = true
        } label: {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: "building.columns")
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(
                        viewModel.selectedUniversity == nil
                            ? VitaColors.textSecondary
                            : VitaColors.accent
                    )
                    .frame(width: VitaTokens.Spacing._2xl)

                if let selected = viewModel.selectedUniversity {
                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.xs) {
                        HStack(spacing: VitaTokens.Spacing.sm) {
                            Text(selected.displayName)
                                .font(VitaTypography.bodyLarge)
                                .foregroundStyle(VitaColors.textPrimary)
                                .lineLimit(1)

                            if let score = selected.enameConcept, score > 0 {
                                ENAMEDBadge(score: score)
                            }
                        }

                        Text("\(selected.city) · \(selected.state)")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(String(localized: "onboarding_university_placeholder"))
                        .font(VitaTypography.bodyLarge)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .frame(
                minHeight: VitaTokens.Spacing._4xl + VitaTokens.Spacing.sm
            )
            .background {
                RoundedRectangle(
                    cornerRadius: VitaTokens.Radius.lg,
                    style: .continuous
                )
                .fill(VitaColors.surfaceElevated.opacity(0.78))
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: VitaTokens.Radius.lg,
                    style: .continuous
                )
                .stroke(
                    viewModel.selectedUniversity == nil
                        ? VitaColors.accent.opacity(0.28)
                        : VitaColors.accent.opacity(0.58),
                    lineWidth: 1
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboardingUniversityPickerButton")
    }

    private var semesterPicker: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            Text(String(localized: "onboarding_semester_question"))
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.textSecondary)

            LazyVGrid(columns: semesterColumns, spacing: VitaTokens.Spacing.sm) {
                ForEach(1...12, id: \.self) { semester in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.selectSemester(semester)
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
                    .accessibilityLabel(
                        String(
                            format: String(localized: "onboarding_semester_accessibility"),
                            semester
                        )
                    )
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
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
