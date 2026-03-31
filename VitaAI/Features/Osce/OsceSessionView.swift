import SwiftUI

// MARK: - OsceSessionView — active case phase

struct OsceSessionView: View {
    @Bindable var viewModel: OsceViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Step stepper
            OsceStepperRow(
                currentStep: viewModel.currentStep,
                totalSteps: OsceViewModel.stepNames.count,
                stepNames: OsceViewModel.stepNames
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Patient context card
            if let ctx = viewModel.patientContext {
                PatientContextCard(ctx: ctx)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }

            // Conversation
            OsceConversationList(
                exchanges: viewModel.exchanges,
                currentPrompt: viewModel.currentPrompt,
                isStreaming: viewModel.isStreaming
            )

            // Error
            if let error = viewModel.error {
                Text(error)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.dataRed)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }

            // Input row
            OsceInputRow(
                value: $viewModel.currentResponse,
                isStreaming: viewModel.isStreaming,
                onSubmit: viewModel.submitResponse
            )
        }
    }
}

// MARK: - Step Stepper

private struct OsceStepperRow: View {
    let currentStep: Int
    let totalSteps: Int
    let stepNames: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...totalSteps, id: \.self) { step in
                let isDone = step < currentStep
                let isCurrent = step == currentStep

                HStack(spacing: 0) {
                    VStack(spacing: 3) {
                        ZStack {
                            Circle()
                                .fill(isDone || isCurrent ? VitaColors.accent : VitaColors.surfaceElevated)
                                .frame(width: 24, height: 24)
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(VitaColors.surface)
                            } else {
                                Text("\(step)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isCurrent ? VitaColors.surface : VitaColors.textTertiary)
                            }
                        }
                        Text(String(stepNames[step - 1].prefix(7)))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(isCurrent ? VitaColors.accent : VitaColors.textTertiary)
                            .lineLimit(1)
                    }

                    if step < totalSteps {
                        Rectangle()
                            .fill(step < currentStep ? VitaColors.accent : VitaColors.surfaceElevated)
                            .frame(height: 1.5)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: step < totalSteps ? .infinity : nil)
            }
        }
    }
}

// MARK: - Patient Context Card

private struct PatientContextCard: View {
    let ctx: OscePatientContext

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.accent)
                    Text("\(ctx.name), \(ctx.age) anos, \(ctx.sex)")
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                }
                Text("Queixa: \(ctx.chiefComplaint)")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                Text("PA: \(ctx.vitalSigns.bp) · FC: \(ctx.vitalSigns.hr) bpm · FR: \(ctx.vitalSigns.rr) irpm · T: \(String(format: "%.1f", ctx.vitalSigns.temp))°C · SpO₂: \(ctx.vitalSigns.spo2)%")
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Conversation List

private struct OsceConversationList: View {
    let exchanges: [OsceViewModel.OsceExchange]
    let currentPrompt: String
    let isStreaming: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(exchanges) { exchange in
                        ExchangeBubble(exchange: exchange)
                    }
                    if !currentPrompt.isEmpty {
                        AiBubble(text: currentPrompt, isStreaming: isStreaming)
                            .id("bottom")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .padding(.bottom, 8)
            }
            .onChange(of: exchanges.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: currentPrompt.count) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

private struct ExchangeBubble: View {
    let exchange: OsceViewModel.OsceExchange

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Step label
            Label("Passo \(exchange.step): \(exchange.stepName)", systemImage: "checkmark.circle.fill")
                .font(VitaTypography.labelSmall)
                .fontWeight(.medium)
                .foregroundStyle(VitaColors.accent)

            // User response — right-aligned bubble
            HStack {
                Spacer(minLength: 48)
                Text(exchange.userResponse)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(VitaColors.accent.opacity(0.15))
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 14, bottomLeadingRadius: 14,
                            bottomTrailingRadius: 4, topTrailingRadius: 14
                        )
                    )
            }

            // AI evaluation — left-aligned bubble
            HStack {
                Text(exchange.aiEvaluation)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(VitaColors.surfaceCard)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4, bottomLeadingRadius: 14,
                            bottomTrailingRadius: 14, topTrailingRadius: 14
                        )
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4, bottomLeadingRadius: 14,
                            bottomTrailingRadius: 14, topTrailingRadius: 14
                        )
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                Spacer(minLength: 48)
            }
        }
    }
}

private struct AiBubble: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(text.isEmpty ? " " : text)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(VitaColors.surfaceCard)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4, bottomLeadingRadius: 14,
                            bottomTrailingRadius: 14, topTrailingRadius: 14
                        )
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4, bottomLeadingRadius: 14,
                            bottomTrailingRadius: 14, topTrailingRadius: 14
                        )
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                Spacer(minLength: 48)
            }

            if isStreaming {
                StreamingDots()
                    .padding(.leading, 4)
            }
        }
        .id("bottom")
    }
}

private struct StreamingDots: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(VitaColors.accent)
                    .frame(width: 5, height: 5)
                    .opacity(animate ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

// MARK: - Input Row

private struct OsceInputRow: View {
    @Binding var value: String
    let isStreaming: Bool
    let onSubmit: () -> Void

    private var canSend: Bool {
        !value.trimmingCharacters(in: .whitespaces).isEmpty && !isStreaming
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Sua resposta...", text: $value, axis: .vertical)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(VitaColors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                )
                .disabled(isStreaming)

            Button(action: { if canSend { onSubmit() } }) {
                ZStack {
                    Circle()
                        .fill(canSend ? VitaColors.accent : VitaColors.surfaceElevated)
                        .frame(width: 44, height: 44)
                    if isStreaming {
                        ProgressView()
                            .tint(VitaColors.white)
                            .scaleEffect(0.75)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(canSend ? VitaColors.surface : VitaColors.textTertiary)
                    }
                }
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            VitaColors.surfaceElevated
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 1)
        }
    }
}
