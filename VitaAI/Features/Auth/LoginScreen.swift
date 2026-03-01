import SwiftUI

struct LoginScreen: View {
    @Environment(\.appContainer) private var container
    let authManager: AuthManager

    @State private var imageOpacity: Double = 0
    @State private var showGoogle = false
    @State private var showApple = false
    @State private var showEmail = false
    @State private var showFooter = false
    @State private var loadingProvider: LoadingProvider = .none

    // Organic glow animation phases (co-prime durations = no visible loop)
    @State private var glowPhase: Double = 0
    @State private var glowStarted = false

    private enum LoadingProvider {
        case google, apple, email, none
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Background image area with glow
            VStack {
                ZStack {
                    // Placeholder caduceus image area
                    Image(systemName: "cross.vial.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 180)
                        .foregroundStyle(VitaColors.accent.opacity(0.3))
                        .opacity(imageOpacity)

                    // Organic glow overlay
                    if glowStarted {
                        TimelineView(.animation) { timeline in
                            Canvas { context, size in
                                let t = timeline.date.timeIntervalSinceReferenceDate

                                // Core glow — organic breathing
                                let breathA = (sin(t * 0.886) + 1) / 2 // period ~7.1s
                                let breathB = (sin(t * 1.461) + 1) / 2 // period ~4.3s
                                let breathC = (sin(t * 2.166) + 1) / 2 // period ~2.9s
                                let composite = breathA * 0.45 + breathB * 0.35 + breathC * 0.2
                                let alpha = composite * 0.18

                                let cx = size.width * 0.5
                                let cy = size.height * 0.38
                                let radius = size.width * (0.35 + composite * 0.08)

                                let gradient = Gradient(colors: [
                                    VitaColors.accent.opacity(alpha),
                                    VitaColors.accent.opacity(alpha * 0.25),
                                    .clear
                                ])

                                context.fill(
                                    Path(ellipseIn: CGRect(
                                        x: cx - radius, y: cy - radius,
                                        width: radius * 2, height: radius * 2
                                    )),
                                    with: .radialGradient(
                                        gradient,
                                        center: CGPoint(x: cx, y: cy),
                                        startRadius: 0,
                                        endRadius: radius
                                    )
                                )

                                // Head highlight
                                let headAlpha = (breathB * 0.6 + breathC * 0.4) * 0.10
                                let headGradient = Gradient(colors: [
                                    VitaColors.accent.opacity(headAlpha),
                                    .clear
                                ])
                                let headRadius = size.width * 0.13
                                let headCenter = CGPoint(x: cx, y: size.height * 0.19)
                                context.fill(
                                    Path(ellipseIn: CGRect(
                                        x: headCenter.x - headRadius,
                                        y: headCenter.y - headRadius,
                                        width: headRadius * 2,
                                        height: headRadius * 2
                                    )),
                                    with: .radialGradient(
                                        headGradient,
                                        center: headCenter,
                                        startRadius: 0,
                                        endRadius: headRadius
                                    )
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.55)

                Spacer()
            }

            // Bottom gradient fade
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.85), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: UIScreen.main.bounds.height * 0.55)
            }
            .ignoresSafeArea()

            // Content overlay
            VStack(spacing: 0) {
                Spacer()

                if authManager.isLoading {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .scaleEffect(1.2)
                    Spacer().frame(height: 40)
                } else {
                    // Google button
                    if showGoogle {
                        GlassAuthButton(
                            label: "Continuar com Google",
                            icon: AnyView(
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(VitaColors.white)
                            ),
                            isPrimary: true,
                            isLoading: loadingProvider == .google
                        ) {
                            loadingProvider = .google
                            authManager.signInWithGoogle()
                        }
                        .padding(.horizontal, 36)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer().frame(height: 10)

                    // Apple button
                    if showApple {
                        GlassAuthButton(
                            label: "Continuar com Apple",
                            icon: AnyView(
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18))
                                    .foregroundStyle(VitaColors.white)
                            ),
                            isLoading: loadingProvider == .apple
                        ) {
                            loadingProvider = .apple
                            authManager.signInWithApple()
                        }
                        .padding(.horizontal, 36)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer().frame(height: 10)

                    // Email button
                    if showEmail {
                        GlassAuthButton(
                            label: "Continuar com Email",
                            icon: AnyView(
                                Image(systemName: "envelope")
                                    .font(.system(size: 16))
                                    .foregroundStyle(VitaColors.textSecondary)
                            ),
                            isLoading: loadingProvider == .email
                        ) {
                            // TODO: email auth flow
                        }
                        .padding(.horizontal, 36)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                // Error
                if let error = authManager.error {
                    Text(error)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 36)
                }

                Spacer().frame(height: 16)

                // Footer legal
                if showFooter {
                    Text("Ao continuar voce concorda com os ")
                        .foregroundStyle(VitaColors.textTertiary) +
                    Text("Termos de Uso")
                        .foregroundStyle(VitaColors.textSecondary)
                        .underline() +
                    Text(" e ")
                        .foregroundStyle(VitaColors.textTertiary) +
                    Text("Politica de Privacidade")
                        .foregroundStyle(VitaColors.textSecondary)
                        .underline()
                }

                Spacer().frame(height: 28)
            }
            .font(VitaTypography.labelSmall)
            .multilineTextAlignment(.center)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                imageOpacity = 1
            }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.8)) { showGoogle = true }
                try? await Task.sleep(for: .seconds(0.1))
                withAnimation(.easeOut(duration: 0.8)) { showApple = true }
                try? await Task.sleep(for: .seconds(0.1))
                withAnimation(.easeOut(duration: 0.8)) { showEmail = true }
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.easeOut(duration: 0.6)) { showFooter = true }
                glowStarted = true
            }
        }
    }
}
