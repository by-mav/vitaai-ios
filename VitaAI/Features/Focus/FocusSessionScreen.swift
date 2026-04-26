import SwiftUI
import UIKit
import UserNotifications

// MARK: - FocusSessionScreen
//
// Modo Foco SOFT (Rafael 2026-04-25, modelo Forest 100M+ downloads).
//
// Fluxo:
// 1. SETUP — picker de duração (15/25/50/90 min) + (opcional) disciplina.
//    Vita orb persona=.focusing(prop: .hourglass), copy "Foca comigo, {name}?"
// 2. RUNNING — fullscreen, esconde TabBar/TopBar (dismissOnDrag false).
//    Vita orb pulsando + countdown grande mono. willResignActive registra leak
//    (timestamp + duração no foreground anterior). willEnterForeground volta
//    pro app. Push agressivo "Volta agora — XX:XX restantes" se leak > 5s.
// 3. END — celebração se completed, mascote .empathetic se cancelou.
//    XP awarded vem do backend (POST /api/study/focus/session/{id}/end).
//
// HARD mode (Family Controls) chega depois — Apple aprova entitlement em
// 3-8 semanas. Soft entrega 70% do valor (Forest provou).

struct FocusSessionScreen: View {
    var onBack: (() -> Void)?

    @Environment(\.appContainer) private var container

    enum Phase { case setup, running, ended }
    @State private var phase: Phase = .setup

    // Setup
    @State private var selectedMinutes: Int = 25
    private let presets = [15, 25, 50, 90]

    // Running
    @State private var sessionId: String?
    @State private var startedAt: Date?
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var leaks: [EndFocusSessionRequestLeaksInner] = []
    @State private var leftAt: Date?  // marca quando user saiu do app

    // End
    @State private var endResult: EndFocusSession200Response?
    @State private var endError: String?

    @State private var isStarting = false
    @State private var isEnding = false

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            switch phase {
            case .setup:    setupView
            case .running:  runningView
            case .ended:    endView
            }
        }
        .trackScreen("FocusSession")
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            handleAppLeave()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            handleAppReturn()
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.75))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            Spacer()

            VitaSpeakingMascot(
                persona: .focusing(),
                size: 140,
                speech: "Bora focar, {name}? Eu seguro a contagem.",
                userName: container.authManager.userName
            )

            // Duration picker — chips grandes
            VStack(spacing: 14) {
                Text("Por quanto tempo?")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { min in
                        durationChip(minutes: min)
                    }
                }
            }
            .padding(.top, 32)

            Spacer()

            Button(action: { Task { await startSession() } }) {
                HStack(spacing: 10) {
                    if isStarting {
                        ProgressView().controlSize(.small).tint(VitaColors.accentLight)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(isStarting ? "Começando..." : "Começar foco de \(selectedMinutes)min")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(VitaColors.accent.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(VitaColors.accentHover.opacity(0.30), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isStarting)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func durationChip(minutes: Int) -> some View {
        Button(action: {
            selectedMinutes = minutes
            HapticManager.shared.fire(.light)
        }) {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("min")
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.65)
            }
            .foregroundStyle(
                selectedMinutes == minutes
                    ? VitaColors.accentLight.opacity(0.95)
                    : VitaColors.textWarm.opacity(0.45)
            )
            .frame(width: 64, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        selectedMinutes == minutes
                            ? VitaColors.accent.opacity(0.20)
                            : VitaColors.glassInnerLight.opacity(0.06)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                selectedMinutes == minutes
                                    ? VitaColors.accentHover.opacity(0.30)
                                    : VitaColors.textWarm.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Running

    private var runningView: some View {
        VStack {
            Spacer()

            // Mascote pulsando + ampulheta
            VitaSpeakingMascot(
                persona: .focusing(timeLeft: TimeInterval(remainingSeconds)),
                size: 180,
                speech: nil,
                userName: nil
            )
            .padding(.bottom, 24)

            // Countdown grande
            Text(formatTime(remainingSeconds))
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .foregroundStyle(VitaColors.textPrimary)
                .kerning(2)

            Text("\(selectedMinutes) min de foco")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                .padding(.top, 4)

            if !leaks.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("\(leaks.count) saída\(leaks.count > 1 ? "s" : "") detectada\(leaks.count > 1 ? "s" : "")")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(VitaColors.dataAmber.opacity(0.75))
                .padding(.top, 12)
            }

            Spacer()

            Button(action: { Task { await endSession(completed: false) } }) {
                Text(isEnding ? "Encerrando..." : "Cancelar foco")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VitaColors.dataRed.opacity(0.75))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(VitaColors.dataRed.opacity(0.06))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isEnding)
            .padding(.bottom, 40)
        }
    }

    // MARK: - End

    private var endView: some View {
        VStack(spacing: 24) {
            Spacer()

            let xp = endResult?.xpAwarded ?? 0
            let completed = (endResult?.completed ?? false) == true

            VitaSpeakingMascot(
                persona: completed && xp > 0 ? .celebrating() : .empathetic,
                size: 140,
                speech: completed && xp > 0
                    ? "Bons estudos, {name}! +\(xp) XP."
                    : completed
                        ? "Bom esforço! Próxima rende mais XP."
                        : "Sem stress. Tenta de novo quando quiser.",
                userName: container.authManager.userName
            )

            if let endResult, endResult.completed == true {
                VStack(spacing: 10) {
                    statBadge(label: "Tempo", value: formatTime(endResult.actualDurationSeconds ?? 0))
                    if (endResult.leaksRecorded ?? 0) > 0 {
                        statBadge(label: "Saídas", value: "\(endResult.leaksRecorded ?? 0)")
                    }
                    if xp > 0 {
                        statBadge(label: "XP ganho", value: "+\(xp)")
                    }
                }
            }

            if let endError {
                Text(endError)
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.dataRed.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button(action: { onBack?() }) {
                Text("Voltar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(VitaColors.accent.opacity(0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func statBadge(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VitaColors.accentLight.opacity(0.92))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VitaColors.glassInnerLight.opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - Logic

    private var totalSeconds: Int { selectedMinutes * 60 }
    private var remainingSeconds: Int { max(0, totalSeconds - elapsedSeconds) }

    private func startSession() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        do {
            let resp = try await container.api.startFocusSession(plannedDurationMinutes: selectedMinutes)
            sessionId = resp.id
            startedAt = Date()
            elapsedSeconds = 0
            leaks = []
            HapticManager.shared.fire(.success)
            withAnimation(.easeInOut(duration: 0.3)) { phase = .running }
            startTimer()
        } catch {
            HapticManager.shared.fire(.error)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsedSeconds += 1
                if remainingSeconds == 0 {
                    await endSession(completed: true)
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func endSession(completed: Bool) async {
        guard !isEnding, let sessionId else { return }
        isEnding = true
        defer { isEnding = false }

        stopTimer()

        do {
            let resp = try await container.api.endFocusSession(
                id: sessionId,
                completed: completed,
                leaks: leaks
            )
            endResult = resp
            HapticManager.shared.fire(completed ? .success : .light)
            if completed && (resp.xpAwarded ?? 0) > 0 {
                SoundManager.shared.play(.levelUp)
            }
            withAnimation(.easeInOut(duration: 0.3)) { phase = .ended }
        } catch {
            endError = "Não conseguimos registrar a sessão. Sua dedicação contou — XP fica pra próxima."
            withAnimation(.easeInOut(duration: 0.3)) { phase = .ended }
        }
    }

    // MARK: - Leak detection

    private func handleAppLeave() {
        guard phase == .running else { return }
        leftAt = Date()
        // Push agressivo (lembrete que volta) — local notification dispara
        // 1s depois mesmo com app em background.
        Task {
            await VitaNotificationCenter.shared.scheduleFocusReturnReminder(
                remainingSeconds: remainingSeconds
            )
        }
    }

    private func handleAppReturn() {
        guard phase == .running, let leftAt else { return }
        let durationMs = Int(Date().timeIntervalSince(leftAt) * 1000)
        if durationMs > 1500 {  // ignora micro-blips (notif do iOS)
            leaks.append(EndFocusSessionRequestLeaksInner(
                at: leftAt,
                durationMs: durationMs
            ))
            HapticManager.shared.fire(.warning)
        }
        self.leftAt = nil
    }

    // MARK: - Format

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Local notification helper (stub se VitaNotificationCenter não exposto)

private final class VitaNotificationCenter {
    static let shared = VitaNotificationCenter()

    @MainActor
    func scheduleFocusReturnReminder(remainingSeconds: Int) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Volta pro foco"
        content.body = "Faltam \(remainingSeconds / 60):\(String(format: "%02d", remainingSeconds % 60)). Não perde tua streak."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: "vita.focus.return.\(UUID().uuidString)", content: content, trigger: trigger)
        try? await center.add(req)
    }
}
