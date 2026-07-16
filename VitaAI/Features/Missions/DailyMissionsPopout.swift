import SwiftUI

// MARK: - DailyMissionsPopout — o quadro de missões do dia (tap na placa)
//
// Rafael 2026-07-16: "abre o menu bem bonito tipo jogo mesmo, com um popout
// com as missões do dia, uma cerquinha bem desenhada, capricha".
//
// Peça de MUNDO, não de app: madeira do mundo da trilha (TrailWorld), moldura
// de tábuas entalhada com parafusos nos cantos, o Vita NPC espiando por cima
// da borda com um balão de fala, e cada missão numa "plaquinha" de medalha
// (bronze/prata/ouro) com barra de progresso embutida no entalhe.
//
// Lei §2.12 (luz e matéria): tudo que é TÁTIL (moldura, plaquinhas, botão de
// resgate) tem gradiente + highlight especular no topo + sombra; o pergaminho
// e o texto ficam planos de propósito. O resgate solta a moeda voando pro
// saldo — a recompensa tem que ser SENTIDA.
//
// Estado vem todo do MissionStore (backend = SOT). O popout não calcula nada.

struct DailyMissionsPopout: View {
    @ObservedObject var store: MissionStore
    let onDismiss: () -> Void
    /// Missão incompleta tocada → leva pra ferramenta que gera o progresso.
    let onGo: (MissionDestination) -> Void

    @Environment(\.appContainer) private var container
    @State private var isVisible = false
    @State private var coinBurst: String?   // id da missão que acabou de pagar

    var body: some View {
        ZStack {
            // Scrim: escurece o mundo e fecha no tap fora.
            // vita-modals-ignore: scrim do popout de mundo (tap-outside), não overlay de sistema
            Color.black.opacity(isVisible ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            board
                .scaleEffect(isVisible ? 1 : 0.86)
                .opacity(isVisible ? 1 : 0)
                .padding(.horizontal, 18)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) { isVisible = true }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.16)) { isVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { onDismiss() }
    }

    /// Quanto falta até o corte diário (meia-noite America/Sao_Paulo, mesmo do
    /// backend). "2h 14m" · "43m" na última hora · "agora" no fio.
    static func timeLeft(from now: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        guard let midnight = cal.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return "—" }
        let secs = max(0, Int(midnight.timeIntervalSince(now)))
        let h = secs / 3600, m = (secs % 3600) / 60
        if secs < 60 { return "agora" }
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }

    // MARK: - O quadro

    private var board: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(TrailWorld.wood.opacity(0.55)).padding(.horizontal, 14)
            content
        }
        .background(boardSurface)
        .overlay(fence)                       // a cerquinha entalhada
        .overlay(alignment: .topLeading) { npc }
        .shadow(color: .black.opacity(0.55), radius: 26, y: 14)
        .frame(maxWidth: 420)
    }

    /// Superfície: pergaminho quente sobre madeira, com luz vindo de cima-esquerda.
    private var boardSurface: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
            .fill(
                LinearGradient(
                    colors: [TrailWorld.stoneTop, TrailWorld.fieldBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                // brilho quente no topo (a "luz do poste" batendo no quadro)
                RoundedRectangle(cornerRadius: 18, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
                    .fill(
                        RadialGradient(
                            colors: [TrailWorld.fireflyGold.opacity(0.16), .clear],
                            center: .topLeading, startRadius: 4, endRadius: 300
                        )
                    )
            )
    }

    /// Cerquinha: moldura de tábua com bisel de luz no topo e parafusos nos cantos.
    private var fence: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
                .strokeBorder(
                    LinearGradient(
                        colors: [TrailWorld.roofTop, TrailWorld.wood, TrailWorld.roofBottom],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 7
                )
            RoundedRectangle(cornerRadius: 18, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
                .inset(by: 3)
                .strokeBorder(TrailWorld.fireflyWarm.opacity(0.30), lineWidth: 1)   // fio de luz (rim light)
            RoundedRectangle(cornerRadius: 13, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
                .inset(by: 8)
                .strokeBorder(.black.opacity(0.28), lineWidth: 1.5)                 // entalhe interno
            screws
        }
        .allowsHitTesting(false)
    }

    private var screws: some View {
        GeometryReader { geo in
            ForEach(0..<4, id: \.self) { i in
                let x: CGFloat = i % 2 == 0 ? 15 : geo.size.width - 15
                let y: CGFloat = i < 2 ? 15 : geo.size.height - 15
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [TrailWorld.fireflyWarm, TrailWorld.roadEdge],
                            center: .topLeading, startRadius: 0, endRadius: 5
                        )
                    )
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(.black.opacity(0.35), lineWidth: 0.6))
                    .position(x: x, y: y)
            }
        }
    }

    /// O Vita NPC + balão, ACIMA da moldura (fora do quadro). Dentro dele o
    /// mascote tapava o título e o balão cobria a 1ª missão (visto no sim).
    private var npc: some View {
        // frame TRAVADO: o OrbMascot desenha coroa/glow fora do `size`, então
        // sem isto o HStack alinhava pelo halo e o balão caía dentro do quadro.
        HStack(alignment: .top, spacing: 7) {
            VitaMascotEquipped(state: .awake, size: 46, bounceEnabled: false)
                .frame(width: 46, height: 46)
                .shadow(color: TrailWorld.fireflyGold.opacity(0.45), radius: 12)
            speechBubble
            Spacer(minLength: 0)
        }
        .frame(height: 46)
        .offset(x: 14, y: -50)
    }

    private var speechBubble: some View {
        Text(npcLine)
            .font(.system(size: 11.5, weight: .bold, design: .rounded))  // ds-allow: arte gamificada (NPC do mundo)
            .foregroundStyle(TrailWorld.fieldBottom)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
                    .fill(
                        LinearGradient(
                            colors: [TrailWorld.fireflyWarm, TrailWorld.fireflyGold],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
                            .stroke(TrailWorld.wood.opacity(0.6), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 168, alignment: .leading)
    }

    private var npcLine: String {
        if store.pendingCount > 0 { return "Tem recompensa te esperando!" }
        if store.missions.allSatisfy(\.claimed) && !store.missions.isEmpty { return "Missões de hoje: feitas. Orgulho!" }
        return "Escolhi 3 missões pra você hoje."
    }

    // MARK: - Header (título + saldo)

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("MISSÕES DO DIA")
                    .font(.system(size: 15, weight: .black, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(TrailWorld.fireflyWarm)
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                // Contagem regressiva viva até o corte (meia-noite BRT) — atualiza
                // a cada minuto via TimelineView.
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    Text("Encerra em \(Self.timeLeft(from: ctx.date))")
                        .font(.system(size: 9.5, weight: .semibold))  // ds-allow: arte gamificada (mundo da trilha)
                        .foregroundStyle(VitaColors.textSecondary)
                        .monospacedDigit()
                }
            }
            Spacer()
            coinPill
            closeButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 11)
    }

    private var coinPill: some View {
        HStack(spacing: 5) {
            CoinIcon(size: 15)
            Text("\(store.coinBalance)")
                .font(.system(size: 13, weight: .black, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(TrailWorld.fireflyWarm)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(TrailWorld.fieldBottom.opacity(0.75))
                .overlay(Capsule().stroke(TrailWorld.wood, lineWidth: 1))
        )
        .animation(.spring(response: 0.4), value: store.coinBalance)
    }

    private var closeButton: some View {
        Button {
            HapticManager.shared.fire(.light)
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .black))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(TrailWorld.fireflyWarm.opacity(0.9))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(TrailWorld.fieldBottom.opacity(0.7))
                        .overlay(Circle().stroke(TrailWorld.wood, lineWidth: 1))
                )
        }
        .padding(.leading, 6)
    }

    // MARK: - Conteúdo

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.missions.isEmpty {
            HStack(spacing: 8) {
                ProgressView().tint(TrailWorld.fireflyGold)
                Text("Consultando o quadro…")
                    .font(.system(size: 12, weight: .semibold))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if store.missions.isEmpty {
            VStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(TrailWorld.fireflyGold.opacity(0.8))
                Text(store.errorMessage ?? "Nenhuma missão hoje.")
                    .font(.system(size: 12, weight: .semibold))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .padding(.horizontal, 20)
        } else {
            VStack(spacing: 9) {
                ForEach(store.missions) { m in
                    MissionPlaque(
                        mission: m,
                        isClaiming: store.claimingId == m.id,
                        burst: coinBurst == m.id,
                        onClaim: { Task { await claim(m) } },
                        onGo: { goTo(m) }
                    )
                }
                bonusRow
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    /// Bônus 3/3 — o "baú extra" do dia.
    private var bonusRow: some View {
        let done = store.missions.allSatisfy(\.claimed) && !store.missions.isEmpty
        return HStack(spacing: 9) {
            Image(systemName: done ? "star.fill" : "star")
                .font(.system(size: 13, weight: .black))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(done ? TrailWorld.fireflyWarm : VitaColors.textTertiary)
            Text(done ? "As 3 missões do dia: completas!" : "Complete as 3 e ganhe um bônus")
                .font(.system(size: 11, weight: .bold))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(done ? TrailWorld.fireflyWarm : VitaColors.textSecondary)
            Spacer()
            if store.bonus.xpReward > 0 {
                Text("+\(store.bonus.xpReward)")
                    .font(.system(size: 11, weight: .black, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
                    .foregroundStyle(done ? TrailWorld.fireflyWarm : VitaColors.textTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
                .fill(TrailWorld.fieldBottom.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
                        .stroke(
                            done ? TrailWorld.fireflyGold.opacity(0.5) : TrailWorld.wood.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1, dash: done ? [] : [4, 3])
                        )
                )
        )
    }

    /// Vai fazer a missão: fecha o quadro e navega pra ferramenta.
    private func goTo(_ m: DailyMission) {
        guard let dest = MissionDestination(family: m.family) else { return }
        HapticManager.shared.fire(.light)
        onGo(dest)
        dismiss()
    }

    private func claim(_ m: DailyMission) async {
        HapticManager.shared.fire(.medium)
        let ok = await store.claim(id: m.id, api: container.api)
        if ok {
            HapticManager.shared.fire(.success)
            withAnimation(.easeOut(duration: 0.1)) { coinBurst = m.id }
            try? await Task.sleep(for: .milliseconds(850))
            withAnimation { coinBurst = nil }
        }
    }
}

// MARK: - MissionPlaque — a plaquinha de uma missão

private struct MissionPlaque: View {
    let mission: DailyMission
    let isClaiming: Bool
    let burst: Bool
    let onClaim: () -> Void
    let onGo: () -> Void

    /// Incompleta = a linha inteira leva pra ferramenta (fazer a missão).
    /// Completa/resgatada = a linha não navega (o botão PEGAR / selo mandam).
    private var isActionable: Bool { !mission.completed && !mission.claimed }

    var body: some View {
        Group {
            if isActionable {
                Button(action: onGo) { row }.buttonStyle(.plain)
            } else {
                row
            }
        }
    }

    private var row: some View {
        HStack(spacing: 11) {
            medal
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: mission.icon)
                        .font(.system(size: 11, weight: .bold))  // ds-allow: arte gamificada (mundo da trilha)
                        .foregroundStyle(tierColor.opacity(0.95))
                    Text(mission.title)
                        .font(.system(size: 12.5, weight: .bold))  // ds-allow: arte gamificada (mundo da trilha)
                        .foregroundStyle(mission.claimed ? VitaColors.textSecondary : VitaColors.textPrimary)
                        .strikethrough(mission.claimed, color: VitaColors.textTertiary)
                        .lineLimit(1)
                }
                progressBar
            }
            Spacer(minLength: 4)
            trailing
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(plaqueSurface)
        .overlay(alignment: .trailing) { if burst { CoinBurst() } }
    }

    /// Medalha em relevo (bronze/prata/ouro) — gradiente + aro + brilho.
    private var medal: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tierColor, tierColor.opacity(0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 1))
                .overlay(
                    // highlight especular (a luz de cima na peça de metal)
                    Circle()
                        .trim(from: 0.55, to: 0.95)
                        .stroke(.white.opacity(0.55), lineWidth: 1.6)
                        .frame(width: 22, height: 22)
                        .blur(radius: 0.4)
                )
                .shadow(color: tierColor.opacity(mission.claimable ? 0.65 : 0.25), radius: mission.claimable ? 8 : 3)
            Text("+\(mission.xpReward)")
                .font(.system(size: 9.5, weight: .black, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(TrailWorld.fieldBottom)
                .monospacedDigit()
        }
        .opacity(mission.claimed ? 0.5 : 1)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // trilho AFUNDADO (inner shadow = recesso)
                Capsule()
                    .fill(TrailWorld.fieldBottom.opacity(0.85))
                    .overlay(Capsule().stroke(.black.opacity(0.4), lineWidth: 1))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tierColor.opacity(0.85), tierColor],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(mission.fraction > 0 ? 7 : 0, geo.size.width * mission.fraction))
                    .overlay(
                        Capsule()
                            .fill(.white.opacity(0.22))
                            .frame(height: 1.6)
                            .padding(.horizontal, 3)
                            .offset(y: -1.4),
                        alignment: .top
                    )
                    .shadow(color: tierColor.opacity(0.5), radius: 3)
            }
        }
        .frame(height: 7)
        .overlay(alignment: .trailing) {
            Text("\(mission.progress)/\(mission.target)")
                .font(.system(size: 8.5, weight: .black, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(VitaColors.textSecondary)
                .monospacedDigit()
                .offset(x: 0, y: -12)
        }
        .animation(.spring(response: 0.5), value: mission.fraction)
    }

    @ViewBuilder
    private var trailing: some View {
        if mission.claimed {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .bold))  // ds-allow: arte gamificada (mundo da trilha)
                .foregroundStyle(TrailWorld.vialGreen.opacity(0.85))
        } else if mission.claimable {
            Button(action: onClaim) {
                Group {
                    if isClaiming {
                        ProgressView().tint(TrailWorld.fieldBottom).scaleEffect(0.6)
                    } else {
                        Text("PEGAR")
                            .font(.system(size: 10.5, weight: .black, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
                            .foregroundStyle(TrailWorld.fieldBottom)
                    }
                }
                .frame(width: 58, height: 27)
                .background(claimButtonSurface)
            }
            .buttonStyle(.plain)
            .disabled(isClaiming)
            .modifier(ClaimPulse())
        } else {
            // Incompleta → "Ir" (a linha inteira navega pra ferramenta).
            HStack(spacing: 3) {
                Text("IR")
                    .font(.system(size: 10, weight: .black, design: .rounded))  // ds-allow: arte gamificada (mundo da trilha)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .black))  // ds-allow: arte gamificada (mundo da trilha)
            }
            .foregroundStyle(tierColor.opacity(0.9))
            .frame(width: 58)
        }
    }

    /// Botão ELEVADO: gradiente + highlight no topo + sombra (pede o toque).
    private var claimButtonSurface: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [TrailWorld.fireflyWarm, TrailWorld.fireflyGold],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                Capsule()
                    .fill(.white.opacity(0.4))
                    .frame(height: 1.4)
                    .padding(.horizontal, 8)
                    .offset(y: 1.5),
                alignment: .top
            )
            .overlay(Capsule().stroke(TrailWorld.roadEdge.opacity(0.8), lineWidth: 1))
            .shadow(color: TrailWorld.fireflyGold.opacity(0.55), radius: 7, y: 2)
    }

    private var plaqueSurface: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
            .fill(
                LinearGradient(
                    colors: [TrailWorld.stoneWing.opacity(0.9), TrailWorld.fieldTop],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
                    .stroke(
                        mission.claimable ? tierColor.opacity(0.6) : TrailWorld.wood.opacity(0.5),
                        lineWidth: 1
                    )
            )
            .overlay(
                // fio de luz no topo (rim light) — a plaquinha ocupa espaço
                RoundedRectangle(cornerRadius: 11, style: .continuous)  // ds-allow: arte gamificada (quadro de mundo da trilha)
                    .trim(from: 0.06, to: 0.44)
                    .stroke(TrailWorld.fireflyWarm.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
    }

    private var tierColor: Color {
        switch mission.tier {
        case "gold": return TrailWorld.fireflyGold
        case "silver": return Color(red: 0.80, green: 0.82, blue: 0.86)  // ds-allow: medalha de prata (arte gamificada)
        default: return Color(red: 0.80, green: 0.53, blue: 0.31)        // ds-allow: medalha de bronze (arte gamificada)
        }
    }
}

// MARK: - Animações de recompensa

/// Moeda subindo pro saldo quando o resgate confirma.
private struct CoinBurst: View {
    @State private var go = false
    var body: some View {
        CoinIcon(size: 17)
            .offset(x: go ? 4 : -6, y: go ? -60 : 0)
            .opacity(go ? 0 : 1)
            .scaleEffect(go ? 1.5 : 0.85)
            .onAppear { withAnimation(.easeOut(duration: 0.8)) { go = true } }
            .allowsHitTesting(false)
    }
}

/// Respiração do botão "PEGAR" — chama o toque sem piscar.
private struct ClaimPulse: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(on ? 1.06 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) { on = true }
            }
    }
}
