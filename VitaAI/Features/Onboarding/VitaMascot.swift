import SwiftUI

// MARK: - OrbMascot
//
// Generic orb-style mascot used by every ONE agent. Same orb design from the
// Vita iOS LoginScreen, parameterized by a `MascotPalette` so we can ship
// Vita (gold + Asclepius staff with green snake) and Pixio (green/teal, no
// staff) without duplicating animation code.
//
// Pixio palette is a literal port of `_OrbPainter` in
// pixio/apps/mobile_flutter/lib/screens/welcome_screen.dart on monstro —
// teal #2DD4BF + the deep emerald gradient stack. Rafael called it out as
// canonical: same Vita orb, just green.

struct MascotPalette: Equatable {
    let primary: Color        // main brand color (was `teal`)
    let bright: Color         // highlight (was `tealBright`)
    let dim: Color            // shadow (was `tealDim`)
    let sphereInner: Color    // orb body inner (lit cap)
    let sphereMid: Color      // body mid-stop (chromatic identity)
    let sphereOuter: Color    // body outer (terminator side)

    // Vita — warm gold orb. Body has a deep gold-brown chromatic cast so even
    // the unlit side reads "Vita" instead of pure black. Updated 2026-04-18.
    static let vita = MascotPalette(
        primary:     Color(red: 0.784, green: 0.627, blue: 0.314), // gold
        bright:      Color(red: 1.000, green: 0.784, blue: 0.471),
        dim:         Color(red: 0.549, green: 0.392, blue: 0.196),
        sphereInner: Color(red: 0.16,  green: 0.13,  blue: 0.09),  // warm dark
        sphereMid:   Color(red: 0.10,  green: 0.08,  blue: 0.05),  // deep brown
        sphereOuter: Color(red: 0.04,  green: 0.03,  blue: 0.02)   // near-black, gold-tinted
    )

    // Pixio — emerald orb. Body carries a deep emerald cast so the unlit side
    // reads as "Pixio" green instead of pure black. From Flutter `_OrbPainter`
    // base palette but pushed slightly more saturated for chromatic identity.
    static let pixio = MascotPalette(
        primary:     Color(red: 0.176, green: 0.831, blue: 0.749), // #2DD4BF
        bright:      Color(red: 0.369, green: 0.918, blue: 0.831), // #5EEAD4
        dim:         Color(red: 0.059, green: 0.420, blue: 0.376), // #0F6B60
        sphereInner: Color(red: 0.102, green: 0.361, blue: 0.322), // #1A5C52
        sphereMid:   Color(red: 0.058, green: 0.239, blue: 0.218), // #0F3D38
        sphereOuter: Color(red: 0.016, green: 0.071, blue: 0.063)  // #041210
    )

    // — Skins de COR (re-tingem o orb inteiro; desbloqueáveis por mérito).
    //   Mesma estrutura da .vita, só troca a identidade cromática. Arte. —
    static let emerald = MascotPalette(
        primary:     Color(red: 0.20, green: 0.83, blue: 0.52),  // ds-allow: skin color
        bright:      Color(red: 0.51, green: 0.95, blue: 0.68),  // ds-allow: skin color
        dim:         Color(red: 0.06, green: 0.42, blue: 0.28),  // ds-allow: skin color
        sphereInner: Color(red: 0.09, green: 0.30, blue: 0.20),  // ds-allow: skin color
        sphereMid:   Color(red: 0.05, green: 0.19, blue: 0.13),  // ds-allow: skin color
        sphereOuter: Color(red: 0.01, green: 0.06, blue: 0.04)   // ds-allow: skin color
    )
    static let sapphire = MascotPalette(
        primary:     Color(red: 0.30, green: 0.56, blue: 0.98),  // ds-allow: skin color
        bright:      Color(red: 0.56, green: 0.74, blue: 1.00),  // ds-allow: skin color
        dim:         Color(red: 0.13, green: 0.26, blue: 0.60),  // ds-allow: skin color
        sphereInner: Color(red: 0.10, green: 0.16, blue: 0.34),  // ds-allow: skin color
        sphereMid:   Color(red: 0.05, green: 0.09, blue: 0.22),  // ds-allow: skin color
        sphereOuter: Color(red: 0.01, green: 0.03, blue: 0.08)   // ds-allow: skin color
    )
    static let ruby = MascotPalette(
        primary:     Color(red: 0.95, green: 0.30, blue: 0.40),  // ds-allow: skin color
        bright:      Color(red: 1.00, green: 0.55, blue: 0.60),  // ds-allow: skin color
        dim:         Color(red: 0.55, green: 0.12, blue: 0.20),  // ds-allow: skin color
        sphereInner: Color(red: 0.34, green: 0.10, blue: 0.14),  // ds-allow: skin color
        sphereMid:   Color(red: 0.22, green: 0.05, blue: 0.08),  // ds-allow: skin color
        sphereOuter: Color(red: 0.08, green: 0.01, blue: 0.02)   // ds-allow: skin color
    )
    static let amethyst = MascotPalette(
        primary:     Color(red: 0.66, green: 0.44, blue: 0.95),  // ds-allow: skin color
        bright:      Color(red: 0.80, green: 0.63, blue: 1.00),  // ds-allow: skin color
        dim:         Color(red: 0.38, green: 0.22, blue: 0.60),  // ds-allow: skin color
        sphereInner: Color(red: 0.24, green: 0.16, blue: 0.36),  // ds-allow: skin color
        sphereMid:   Color(red: 0.15, green: 0.09, blue: 0.24),  // ds-allow: skin color
        sphereOuter: Color(red: 0.05, green: 0.03, blue: 0.09)   // ds-allow: skin color
    )
}

// MARK: - Skin / acessório do mascote (prototype 2026-07-05)
// Cada peça é uma CAMADA ancorada na geometria real do orb (relativa a `size`)
// e vive dentro do orbView → herda float/bounce/breath (se mexe junto com ele).
// Head items (óculos/toucas) ficam por cima do corpo; não são adesivo — pegam a
// mesma luz de cima. Prova pro Rafael de que skin no orb NÃO fica tosco.
enum MascotAccessory: String, CaseIterable {
    // — Cabeça (topo do orb) —
    case bouffantCap   // touca cirúrgica bufante (streak 7d)
    case gradCap       // capelo de formatura (formou)
    case crown         // coroa — topo do ranking / Lenda
    case headMirror    // espelho frontal de médico (refletor de testa)
    case beanie        // gorro de inverno com pompom
    case laurel        // coroa de louros (acadêmico)
    case capybaraHat   // chapéu de capivara (easter egg da capivara dourada)
    case halo          // auréola dourada divina (LENDÁRIA — do baú)
    case nurseCap      // touca de enfermeira (cruz vermelha)
    case sleepMask     // máscara de dormir na testa (viradas de noite)
    case headphones    // fones de ouvido (música pra estudar)
    case partyHat      // chapéu de festa (comemoração)
    case santaHat      // gorro de Natal (sazonal)
    case wizardHat     // chapéu de mago (épico — sabedoria)
    case catEars       // orelhas de gato (fofo)
    case flowerCrown   // coroa de flores (primavera)
    case devilHorns    // chifrinhos de diabo (travesso)
    case topHat        // cartola (formal chique)
    // — Rosto (olhos) —
    case glassesRound  // óculos redondos finos (estudo)
    case glassesRect   // óculos retos/estudioso
    case sunglasses    // óculos de sol aviador (streak 30d)
    case surgicalMask  // máscara cirúrgica
    case monocle       // monóculo (nobre)
    case n95Mask       // respirador N95 (com válvula)
    case faceShield    // protetor facial (viseira transparente)
    case mustache      // bigode (divertido)
    case eyePatch      // tapa-olho (pirata / pós-op)
    case clownNose     // nariz de palhaço (divertido)
    case heartGlasses  // óculos de coração (fofo)
    // — Pescoço / corpo (base do orb) —
    case stethoscope   // estetoscópio pendurado
    case labCoat       // gola de jaleco branco
    case bowTie        // gravata-borboleta
    case scarf         // cachecol
    case goldMedal     // medalha de ouro (campeão)
    case idBadge       // crachá hospitalar no cordão
    case tie           // gravata (formal / apresentação)
    case goldChain     // corrente de ouro (bling)

    /// Slot anatômico — pra galeria e (futuro) sistema de equipar por camada.
    var slot: String {
        switch self {
        case .bouffantCap, .gradCap, .crown, .headMirror, .beanie, .laurel, .capybaraHat, .halo, .nurseCap,
             .sleepMask, .headphones, .partyHat, .santaHat, .wizardHat, .catEars, .flowerCrown, .devilHorns, .topHat:
            return "Cabeça"
        case .glassesRound, .glassesRect, .sunglasses, .surgicalMask, .monocle, .n95Mask, .faceShield,
             .mustache, .eyePatch, .clownNose, .heartGlasses:
            return "Rosto"
        case .stethoscope, .labCoat, .bowTie, .scarf, .goldMedal, .idBadge, .tie, .goldChain:
            return "Pescoço"
        }
    }

    /// Rótulo curto pra galeria.
    var label: String {
        switch self {
        case .bouffantCap: return "Touca"
        case .gradCap:     return "Capelo"
        case .crown:       return "Coroa"
        case .headMirror:  return "Refletor"
        case .beanie:      return "Gorro"
        case .laurel:      return "Louros"
        case .capybaraHat: return "Capivara"
        case .halo:        return "Auréola"
        case .nurseCap:    return "Touca enfermagem"
        case .sleepMask:   return "Máscara de dormir"
        case .headphones:  return "Fones"
        case .partyHat:    return "Chapéu de festa"
        case .tie:         return "Gravata"
        case .santaHat:    return "Gorro de Natal"
        case .wizardHat:   return "Chapéu de mago"
        case .catEars:     return "Orelhas de gato"
        case .mustache:    return "Bigode"
        case .eyePatch:    return "Tapa-olho"
        case .flowerCrown: return "Coroa de flores"
        case .devilHorns:  return "Chifrinhos"
        case .topHat:      return "Cartola"
        case .clownNose:   return "Nariz de palhaço"
        case .heartGlasses: return "Óculos de coração"
        case .goldChain:   return "Corrente de ouro"
        case .n95Mask:     return "Respirador N95"
        case .faceShield:  return "Protetor facial"
        case .idBadge:     return "Crachá"
        case .glassesRound: return "Redondo"
        case .glassesRect:  return "Reto"
        case .sunglasses:   return "Sol"
        case .surgicalMask: return "Máscara"
        case .monocle:      return "Monóculo"
        case .stethoscope:  return "Estetosc."
        case .labCoat:      return "Jaleco"
        case .bowTie:       return "Gravata"
        case .scarf:        return "Cachecol"
        case .goldMedal:    return "Medalha"
        }
    }
}

// MARK: - Geometria do orb (o "corpo" mapeado)
//
// Raio = 0.5·s, origem no CENTRO do orb. Serve pras peças seguirem a silhueta
// REAL da esfera (largura por latitude) em vez de offsets chutados. É isto que
// deixa uma banda/gola CURVAR com a bola e uma peça DAR A VOLTA (oclusão).
private enum OrbGeo {
    static let radius: CGFloat = 0.5
    static let crownY: CGFloat = -0.50   // topo
    static let browY:  CGFloat = -0.16   // linha da testa (acima dos olhos)
    static let eyeY:   CGFloat = -0.02   // olhos
    static let baseY:  CGFloat =  0.42   // onde golas/cachecol abraçam a base
    /// meia-largura da esfera (silhueta) na latitude y — unidades de s.
    static func halfWidth(_ y: CGFloat) -> CGFloat {
        let yy = Swift.min(Swift.abs(y), radius)
        return (radius * radius - yy * yy).squareRoot()
    }
}

struct OrbMascot: View {
    var palette: MascotPalette = .vita
    var state: VitaMascotState = .awake
    var size: CGFloat = 120
    // Skins equipadas — no máx 1 por slot (cabeça/rosto/pescoço). Vazio = orb
    // puro (todo uso existente). A ordem de desenho respeita o slot (pescoço
    // atrás → cabeça → rosto na frente).
    var accessories: [MascotAccessory] = []
    // Thumbnail estático: desliga TODA animação (float/glow/aura/sparkle/loops)
    // pra galeria não derreter o FPS renderizando dezenas de orbs de uma vez.
    var animated: Bool = true
    // Nome bordado no jaleco ("Dr. <nome>"). No app real = 1º nome/apelido do
    // perfil; nil = sem bordado. Só aparece com a skin de jaleco equipada.
    var nameTag: String? = nil
    // Foto do perfil (OAuth) — usada no crachá LENDÁRIO (foto + nome + "MÉDICO").
    // nil = silhueta. Vem do authManager.userImage nos callsites com perfil.
    var photoURL: URL? = nil
    // Staff/snake removed entirely on 2026-04-18 — Rafael called it ugly and
    // wanted the orb to stand on its own. Param kept for source compat (no-op).
    var showStaff: Bool = false
    // When false, the orb's periodic "bounce" is suppressed. Useful for
    // screens where the bounce competes with the user's task — e.g. the
    // Transcrição recorder where the orb needs to look focused, not excited.
    var bounceEnabled: Bool = true
    // When false, o "bob" vertical (float ocioso) também é suprimido — usado
    // pelo provador de skins pra o Vita ficar PARADO e facilitar ver o encaixe
    // das peças (Rafael 2026-07-05: "para de ficar pulando, subindo e descendo").
    var bob: Bool = true
    // When false, ALL idle animations stop (float, breath, head tilt, drift,
    // pulse, blink) AND eyes are hidden. Used by LoginScreen pre-drag state
    // where the orb is meant to look "asleep, hiding under the screen edge".
    var idleEnabled: Bool = true
    // When true, draws two rosy cheeks on the orb (envergonhado). Used pelo
    // VitaOnboarding logo após o user acordar a Vita: ela fala "Oiii, não tinha
    // te visto aí" enquanto cora rapidamente. Rafael 2026-04-28.
    var isBlushing: Bool = false

    @State private var floatY: CGFloat = 0
    @State private var glowIntensity: Double = 0.3
    @State private var blinking = false
    @State private var sparklePhase: Double = 0
    @State private var breathScale: CGFloat = 1.0
    @State private var eyeLookX: CGFloat = 0
    @State private var ringRotation: Double = 0
    @State private var bounceY: CGFloat = 0
    @State private var squishY: CGFloat = 1.0
    @State private var squishX: CGFloat = 1.0
    @State private var auraHue: Double = 0
    @State private var eyeAngle: Double = 0
    @State private var loopTask: Task<Void, Never>? = nil
    // New behavior states (gold-standard pass)
    @State private var headTilt: Double = 0       // -8..8 degrees, micro head movement
    @State private var idleDriftX: CGFloat = 0    // tiny horizontal sway
    @State private var pulseBoost: Double = 0     // 0..1 magical pulse on the ring/aura
    @State private var slowBlink: Bool = false    // longer half-close (drowsy)
    @State private var happyEyes: Bool = false    // ^_^ closed-arc smile eyes

    private var primary: Color { palette.primary }
    private var bright: Color  { palette.bright }
    private var dim: Color     { palette.dim }

    var body: some View {
        ZStack {
            if animated { auraView }
            orbView
        }
        .scaleEffect(x: breathScale * squishX, y: breathScale * squishY)
        .offset(x: idleDriftX, y: bounceY)
        .onAppear { startAnimations() }
        .onDisappear {
            loopTask?.cancel()
            loopTask = nil
            floatY = 0; glowIntensity = 0.3; sparklePhase = 0; breathScale = 1.0
            ringRotation = 0; auraHue = 0
            eyeAngle = 0; bounceY = 0; squishY = 1.0; squishX = 1.0
            eyeLookX = 0; blinking = false
            headTilt = 0; idleDriftX = 0; pulseBoost = 0; slowBlink = false
            happyEyes = false
        }
        .onChange(of: state) { newState in
            if newState == .happy { triggerBounce() }
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.7), value: state)
    }

    // MARK: - Aura
    private var auraView: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hue: auraHue.truncatingRemainder(dividingBy: 1.0), saturation: 0.6, brightness: 0.9).opacity(0.08),
                        Color(hue: (auraHue + 0.3).truncatingRemainder(dividingBy: 1.0), saturation: 0.5, brightness: 0.8).opacity(0.04),
                        .clear,
                    ],
                    center: .center, startRadius: size * 0.3, endRadius: size * 1.0
                )
            )
            .frame(width: size * 2.2, height: size * 2.2)
            .blur(radius: 20)
            .opacity(state == .sleeping ? 0.3 : 0.7)
    }

    // MARK: - Orb
    private var orbView: some View {
        ZStack {
            if animated { orbGlow; orbSparkles }
            orbRing
            accessoryBehindLayer   // parte da skin que dá a volta (some atrás do corpo)
            orbBody
            accessoryLayer         // parte da skin na frente
        }
        .offset(y: floatY)
    }

    // Camada ATRÁS do corpo — só aparece além da silhueta do orb, então lê como
    // "a peça deu a volta na cabeça" (oclusão real, não desenho por cima).
    @ViewBuilder private var accessoryBehindLayer: some View {
        let s = size
        ForEach(accessories.sorted { slotZ($0) < slotZ($1) }, id: \.self) { acc in
            accessoryBehind(acc, s)
        }
    }

    @ViewBuilder private func accessoryBehind(_ accessory: MascotAccessory, _ s: CGFloat) -> some View {
        // Parte de trás por item entra aqui conforme eu rolo o sistema pros
        // demais (hastes dos óculos, volta do cachecol, tubo do estetoscópio nos
        // ombros). Cabeça/topo NÃO usa (dava halo duplicado).
        switch accessory {
        default: EmptyView()
        }
    }

    // MARK: - Camada de skin (ancorada no orb, relativa a `size`)
    @ViewBuilder private var accessoryLayer: some View {
        let s = size
        // pescoço (atrás) → cabeça → rosto (na frente)
        ForEach(accessories.sorted { slotZ($0) < slotZ($1) }, id: \.self) { acc in
            drawAccessory(acc, s)
        }
    }

    private func slotZ(_ a: MascotAccessory) -> Int {
        switch a.slot {
        case "Pescoço": return 0
        case "Cabeça":  return 1
        default:        return 2   // Rosto na frente
        }
    }

    @ViewBuilder private func drawAccessory(_ accessory: MascotAccessory, _ s: CGFloat) -> some View {
        ZStack {
            // Sombra de contato — a peça de cabeça projeta sombra na "testa" do
            // orb, então lê como APOIADA na superfície, não colada por cima.
            if accessory.slot == "Cabeça" {
                Ellipse().fill(Color.black.opacity(0.24))
                    .frame(width: s * 0.56, height: s * 0.14)
                    .offset(y: -s * 0.19).blur(radius: s * 0.035)
            }
            accessoryArt(accessory, s)
        }
    }

    @ViewBuilder private func accessoryArt(_ accessory: MascotAccessory, _ s: CGFloat) -> some View {
        switch accessory {
        case .glassesRound: glassesView(s, round: true)
        case .glassesRect:  glassesView(s, round: false)
        case .sunglasses:   sunglassesView(s)
        case .surgicalMask: surgicalMaskView(s)
        case .monocle:      monocleView(s)
        case .bouffantCap:  bouffantCapView(s)
        case .gradCap:      gradCapView(s)
        case .crown:        crownView(s)
        case .headMirror:   headMirrorView(s)
        case .beanie:       beanieView(s)
        case .laurel:       laurelView(s)
        case .capybaraHat:  capybaraHatView(s)
        case .halo:         haloView(s)
        case .nurseCap:     nurseCapView(s)
        case .sleepMask:    sleepMaskView(s)
        case .headphones:   headphonesView(s)
        case .partyHat:     partyHatView(s)
        case .tie:          tieView(s)
        case .santaHat:     santaHatView(s)
        case .wizardHat:    wizardHatView(s)
        case .catEars:      catEarsView(s)
        case .mustache:     mustacheView(s)
        case .eyePatch:     eyePatchView(s)
        case .flowerCrown:  flowerCrownView(s)
        case .devilHorns:   devilHornsView(s)
        case .topHat:       topHatView(s)
        case .clownNose:    clownNoseView(s)
        case .heartGlasses: heartGlassesView(s)
        case .goldChain:    goldChainView(s)
        case .n95Mask:      n95MaskView(s)
        case .faceShield:   faceShieldView(s)
        case .idBadge:      idBadgeView(s)
        case .stethoscope:  stethoscopeView(s)
        case .labCoat:      labCoatView(s)
        case .bowTie:       bowTieView(s)
        case .scarf:        scarfView(s)
        case .goldMedal:    goldMedalView(s)
        }
    }

    // Óculos — lentes finas com tom de vidro sobre os olhos, ponte + hastes.
    // round=true → redondas; false → retangulares (estudioso).
    @ViewBuilder private func glassesView(_ s: CGFloat, round: Bool) -> some View {
        let metal = Color(red: 0.86, green: 0.73, blue: 0.44)   // ds-allow: skin color (ouro fosco)
        let glass = Color(red: 0.60, green: 0.76, blue: 0.92).opacity(0.12)  // ds-allow: skin color
        let lensW: CGFloat = round ? s * 0.225 : s * 0.25
        let lensH: CGFloat = round ? s * 0.225 : s * 0.185
        let dx: CGFloat = round ? s * 0.125 : s * 0.135
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { sign in
                ZStack {
                    lensShape(round: round, s: s).fill(glass)
                    lensShape(round: round, s: s).stroke(metal, lineWidth: s * 0.016)
                    Capsule().fill(Color.white.opacity(0.5))
                        .frame(width: s * 0.012, height: s * 0.055)
                        .rotationEffect(.degrees(-30))
                        .offset(x: -s * 0.035, y: -s * 0.03)
                }
                .frame(width: lensW, height: lensH)
                .offset(x: CGFloat(sign) * dx, y: -s * 0.02)
            }
            // ponte
            Capsule().fill(metal).frame(width: dx * 0.7, height: s * 0.016).offset(y: -s * 0.03)
            // hastes que somem pras laterais
            Capsule().fill(metal).frame(width: s * 0.12, height: s * 0.015)
                .offset(x: -(dx + lensW * 0.5 + s * 0.02), y: -s * 0.05)
            Capsule().fill(metal).frame(width: s * 0.12, height: s * 0.015)
                .offset(x: dx + lensW * 0.5 + s * 0.02, y: -s * 0.05)
        }
    }

    private func lensShape(round: Bool, s: CGFloat) -> AnyShape {
        round ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: s * 0.05))
    }

    // Touca cirúrgica — CAPA a calota superior seguindo a esfera (SphereCapShape),
    // banda na linha da testa curvando com a bola (SphereBandArc). A casca de trás
    // vai ATRÁS do corpo (bouffantCapBehind) → dá a volta. Olhos aparecem abaixo.
    private func bouffantCapView(_ s: CGFloat) -> some View {
        let light = Color(red: 0.55, green: 0.83, blue: 0.74)  // ds-allow: skin color
        let mid   = Color(red: 0.36, green: 0.64, blue: 0.56)  // ds-allow: skin color
        let dark  = Color(red: 0.25, green: 0.49, blue: 0.43)  // ds-allow: skin color
        let puff = BouffantShape(browY: OrbGeo.browY)
        return ZStack {
            // corpo de tecido (estufa pra fora)
            puff.fill(LinearGradient(colors: [light, mid], startPoint: .top, endPoint: .bottom))
            // franzido — pares de linha escura+clara em leque, clipados ao pano
            ZStack {
                ForEach(-4...4, id: \.self) { i in
                    Capsule().fill(Color.black.opacity(0.05))
                        .frame(width: s * 0.02, height: s * 0.52)
                        .rotationEffect(.degrees(Double(i) * 11))
                        .offset(x: CGFloat(i) * s * 0.085, y: -s * 0.30)
                    Capsule().fill(Color.white.opacity(0.07))
                        .frame(width: s * 0.012, height: s * 0.52)
                        .rotationEffect(.degrees(Double(i) * 11))
                        .offset(x: CGFloat(i) * s * 0.085 + s * 0.022, y: -s * 0.30)
                }
            }
            .frame(width: s, height: s)
            .clipShape(puff)
            // highlight de tecido (luz de cima-esq)
            Ellipse().fill(Color.white.opacity(0.15))
                .frame(width: s * 0.50, height: s * 0.22)
                .offset(x: -s * 0.14, y: -s * 0.44).blur(radius: s * 0.05)
            // sombra interna pesando o pano perto do elástico
            SphereBandArc(y: OrbGeo.browY, thickness: 0.15)
                .fill(Color.black.opacity(0.15)).blur(radius: s * 0.03).clipShape(puff)
            // elástico franzido na base
            SphereBandArc(y: OrbGeo.browY - 0.015, thickness: 0.05).fill(dark)
            ForEach(-6...6, id: \.self) { i in
                Capsule().fill(Color.black.opacity(0.16))
                    .frame(width: s * 0.008, height: s * 0.035)
                    .offset(x: CGFloat(i) * s * 0.058, y: OrbGeo.browY * s + s * 0.008)
            }
        }
        .frame(width: s, height: s)
    }

    // Capelo de formatura — banda + tábua em perspectiva + borla dourada.
    private func gradCapView(_ s: CGFloat) -> some View {
        let dark = Color(red: 0.15, green: 0.13, blue: 0.11)   // ds-allow: skin color
        let board = Color(red: 0.27, green: 0.24, blue: 0.21)  // ds-allow: skin color
        return ZStack {
            Ellipse().fill(dark).frame(width: s * 0.5, height: s * 0.17).offset(y: -s * 0.33)
            Rectangle()
                .fill(LinearGradient(colors: [board, dark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: s * 0.62, height: s * 0.62)
                .rotationEffect(.degrees(45)).scaleEffect(y: 0.46).offset(y: -s * 0.43)
            Circle().fill(bright).frame(width: s * 0.05, height: s * 0.05).offset(y: -s * 0.43)
            Capsule().fill(primary).frame(width: s * 0.012, height: s * 0.32).offset(x: s * 0.23, y: -s * 0.26)
            Circle().fill(bright).frame(width: s * 0.055, height: s * 0.055).offset(x: s * 0.23, y: -s * 0.08)
        }
    }

    // MARK: Cabeça

    // Coroa — 5 pontas, gemas e aro dourado. Luz de cima. Status "Lenda".
    // Auréola — anel dourado divino flutuando acima da cabeça (LENDÁRIA). Brilho
    // forte + gradiente angular pra parecer luz, não metal.
    private func haloView(_ s: CGFloat) -> some View {
        let goldT = Color(red: 1.00, green: 0.92, blue: 0.58)   // ds-allow: skin color
        let goldM = Color(red: 0.96, green: 0.74, blue: 0.26)   // ds-allow: skin color
        return ZStack {
            // Halo de luz difuso (aura).
            Ellipse()
                .stroke(goldT.opacity(0.55), lineWidth: s * 0.10)
                .frame(width: s * 0.64, height: s * 0.20)
                .offset(y: -s * 0.54)
                .blur(radius: s * 0.06)
            // Anel principal — gradiente angular = brilho girando.
            Ellipse()
                .stroke(
                    AngularGradient(colors: [goldM, goldT, .white, goldT, goldM], center: .center),
                    style: StrokeStyle(lineWidth: s * 0.05)
                )
                .frame(width: s * 0.58, height: s * 0.17)
                .offset(y: -s * 0.54)
                .shadow(color: goldT.opacity(0.85), radius: s * 0.06)
            // Fagulha de destaque.
            Circle().fill(Color.white)
                .frame(width: s * 0.04, height: s * 0.04)
                .offset(x: s * 0.18, y: -s * 0.58)
                .blur(radius: 0.5)
        }
    }

    // Protetor facial — faixa na testa + viseira TRANSPARENTE (olhos aparecem por trás).
    private func faceShieldView(_ s: CGFloat) -> some View {
        let band  = Color(red: 0.30, green: 0.55, blue: 0.72)  // ds-allow: skin color
        let glass = Color(red: 0.72, green: 0.86, blue: 0.96)  // ds-allow: skin color
        return ZStack {
            // Viseira transparente cobrindo o rosto (baixa opacidade = vê os olhos).
            RoundedRectangle(cornerRadius: s * 0.14)
                .fill(glass.opacity(0.20))
                .frame(width: s * 0.62, height: s * 0.54)
                .overlay(RoundedRectangle(cornerRadius: s * 0.14).stroke(glass.opacity(0.5), lineWidth: s * 0.008))
                .offset(y: s * 0.07)
            // Reflexo diagonal no acrílico.
            Capsule().fill(Color.white.opacity(0.28))
                .frame(width: s * 0.055, height: s * 0.40)
                .rotationEffect(.degrees(18))
                .offset(x: -s * 0.15, y: s * 0.04)
            // Faixa de espuma na testa (segura a viseira).
            RoundedRectangle(cornerRadius: s * 0.02).fill(band)
                .frame(width: s * 0.64, height: s * 0.075)
                .offset(y: -s * 0.28)
        }
    }

    // Touca de enfermagem — branca com cruz vermelha (topo da cabeça).
    private func nurseCapView(_ s: CGFloat) -> some View {
        let white = Color(red: 0.97, green: 0.98, blue: 1.00)  // ds-allow: skin color
        let shade = Color(red: 0.80, green: 0.84, blue: 0.90)  // ds-allow: skin color
        let red   = Color(red: 0.85, green: 0.24, blue: 0.28)  // ds-allow: skin color
        return ZStack {
            UnevenRoundedRectangle(topLeadingRadius: s * 0.06, bottomLeadingRadius: s * 0.015,
                                   bottomTrailingRadius: s * 0.015, topTrailingRadius: s * 0.06)
                .fill(LinearGradient(colors: [white, shade], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.48, height: s * 0.22)
                .offset(y: -s * 0.42)
            RoundedRectangle(cornerRadius: s * 0.008).fill(shade.opacity(0.7))
                .frame(width: s * 0.48, height: s * 0.028)
                .offset(y: -s * 0.325)
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.004).fill(red).frame(width: s * 0.10, height: s * 0.032)
                RoundedRectangle(cornerRadius: s * 0.004).fill(red).frame(width: s * 0.032, height: s * 0.10)
            }
            .offset(y: -s * 0.44)
        }
    }

    // Respirador N95 — moldado, branco, com válvula (rosto). Mais bojudo que a cirúrgica.
    private func n95MaskView(_ s: CGFloat) -> some View {
        let white = Color(red: 0.95, green: 0.96, blue: 0.98)  // ds-allow: skin color
        let shade = Color(red: 0.74, green: 0.78, blue: 0.84)  // ds-allow: skin color
        let valve = Color(red: 0.40, green: 0.44, blue: 0.50)  // ds-allow: skin color
        return ZStack {
            // Laços de orelha (baixos, indo pras laterais — não pra cima).
            ForEach([-1.0, 1.0], id: \.self) { sign in
                Capsule().fill(shade)
                    .frame(width: s * 0.02, height: s * 0.20)
                    .rotationEffect(.degrees(Double(sign) * 12))
                    .offset(x: CGFloat(sign) * s * 0.25, y: s * 0.16)
            }
            // Corpo moldado — SÓ nariz+boca (baixo, olhos livres em cima).
            Ellipse()
                .fill(LinearGradient(colors: [white, shade], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.50, height: s * 0.32)
                .offset(y: s * 0.28)
            Capsule().fill(shade.opacity(0.7))
                .frame(width: s * 0.018, height: s * 0.22)
                .offset(y: s * 0.28)
            Circle().fill(valve)
                .frame(width: s * 0.10, height: s * 0.10)
                .overlay(
                    VStack(spacing: s * 0.014) {
                        Capsule().fill(white.opacity(0.45)).frame(width: s * 0.06, height: s * 0.007)
                        Capsule().fill(white.opacity(0.45)).frame(width: s * 0.06, height: s * 0.007)
                    }
                )
                .offset(y: s * 0.31)
        }
    }

    // Crachá médico LENDÁRIO — foto REAL do perfil + nome + "MÉDICO" (Rafael 2026-07-15).
    private func idBadgeView(_ s: CGFloat) -> some View {
        let cord  = Color(red: 0.18, green: 0.46, blue: 0.62)  // ds-allow: skin color
        let card  = Color(red: 0.98, green: 0.99, blue: 1.00)  // ds-allow: skin color
        let strip = Color(red: 0.14, green: 0.42, blue: 0.58)  // ds-allow: skin color
        let line  = Color(red: 0.66, green: 0.72, blue: 0.80)  // ds-allow: skin color
        let ink   = Color(red: 0.16, green: 0.22, blue: 0.30)  // ds-allow: skin color
        let cardW = s * 0.46
        let cardH = s * 0.28
        return ZStack {
            // cordão em V descendo do pescoço
            ForEach([-1.0, 1.0], id: \.self) { sign in
                Capsule().fill(cord)
                    .frame(width: s * 0.022, height: s * 0.24)
                    .rotationEffect(.degrees(Double(sign) * 18))
                    .offset(x: CGFloat(sign) * s * 0.11, y: s * 0.28)
            }
            RoundedRectangle(cornerRadius: s * 0.005).fill(line)
                .frame(width: s * 0.05, height: s * 0.022).offset(y: s * 0.38)
            // cartão do crachá
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: s * 0.022).fill(card)
                    .overlay(RoundedRectangle(cornerRadius: s * 0.022).stroke(line, lineWidth: s * 0.005))
                UnevenRoundedRectangle(topLeadingRadius: s * 0.022, topTrailingRadius: s * 0.022)
                    .fill(strip).frame(height: cardH * 0.22)
                HStack(spacing: s * 0.022) {
                    photoThumb(s)
                        .frame(width: s * 0.11, height: s * 0.11)
                        .clipShape(RoundedRectangle(cornerRadius: s * 0.014))
                        .overlay(RoundedRectangle(cornerRadius: s * 0.014).stroke(line.opacity(0.6), lineWidth: s * 0.004))
                    VStack(alignment: .leading, spacing: s * 0.004) {
                        Text(nameTag ?? "Vita")
                            .font(.system(size: s * 0.05, weight: .bold)).foregroundColor(ink)  // ds-allow: crachá (arte)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text("MÉDICO")
                            .font(.system(size: s * 0.034, weight: .heavy)).foregroundColor(strip)  // ds-allow: crachá (arte)
                            .tracking(s * 0.005)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, s * 0.022)
                .padding(.top, cardH * 0.30)
            }
            .frame(width: cardW, height: cardH)
            .offset(y: s * 0.52)
        }
    }

    // Miniatura da foto do perfil no crachá (ou silhueta enquanto carrega/sem foto).
    @ViewBuilder private func photoThumb(_ s: CGFloat) -> some View {
        let fallback = Color(red: 0.80, green: 0.86, blue: 0.92)  // ds-allow: skin color
        if let photoURL {
            CachedAsyncImage(url: photoURL) {
                ZStack {
                    fallback
                    Image(systemName: "person.fill").resizable().scaledToFit()
                        .foregroundColor(.white.opacity(0.85)).padding(s * 0.02)
                }
            }
        } else {
            ZStack {
                fallback
                Image(systemName: "person.fill").resizable().scaledToFit()
                    .foregroundColor(.white.opacity(0.85)).padding(s * 0.02)
            }
        }
    }

    // Máscara de dormir empurrada na testa (viradas de noite estudando).
    private func sleepMaskView(_ s: CGFloat) -> some View {
        let mask  = Color(red: 0.28, green: 0.24, blue: 0.44)  // ds-allow: skin color
        let hi    = Color(red: 0.46, green: 0.40, blue: 0.64)  // ds-allow: skin color
        let strap = Color(red: 0.22, green: 0.18, blue: 0.36)  // ds-allow: skin color
        return ZStack {
            Capsule().fill(strap)
                .frame(width: s * 0.66, height: s * 0.05).offset(y: -s * 0.20)
            RoundedRectangle(cornerRadius: s * 0.06).fill(mask)
                .frame(width: s * 0.44, height: s * 0.16)
                .overlay(RoundedRectangle(cornerRadius: s * 0.045).stroke(hi.opacity(0.5), lineWidth: s * 0.006).padding(s * 0.022))
                .offset(y: -s * 0.22)
            Capsule().fill(Color.white.opacity(0.18))
                .frame(width: s * 0.16, height: s * 0.02).offset(x: -s * 0.08, y: -s * 0.255)
        }
    }

    // Fones de ouvido — arco por cima + conchas nas laterais (música pra estudar).
    private func headphonesView(_ s: CGFloat) -> some View {
        let band   = Color(red: 0.20, green: 0.22, blue: 0.28)  // ds-allow: skin color
        let cup    = Color(red: 0.13, green: 0.14, blue: 0.19)  // ds-allow: skin color
        let accent = Color(red: 0.36, green: 0.72, blue: 1.00)  // ds-allow: skin color
        return ZStack {
            Circle().trim(from: 0.0, to: 0.5)
                .stroke(band, style: StrokeStyle(lineWidth: s * 0.05, lineCap: .round))
                .rotationEffect(.degrees(180))
                .frame(width: s * 0.72, height: s * 0.72).offset(y: -s * 0.05)
            ForEach([-1.0, 1.0], id: \.self) { sign in
                RoundedRectangle(cornerRadius: s * 0.05).fill(cup)
                    .frame(width: s * 0.13, height: s * 0.18)
                    .overlay(RoundedRectangle(cornerRadius: s * 0.03).stroke(accent.opacity(0.7), lineWidth: s * 0.007)
                        .frame(width: s * 0.08, height: s * 0.12))
                    .offset(x: CGFloat(sign) * s * 0.35, y: -s * 0.02)
            }
        }
    }

    // Chapéu de festa — cone listrado + pompom (comemoração).
    private func partyHatView(_ s: CGFloat) -> some View {
        let a   = Color(red: 1.00, green: 0.42, blue: 0.56)  // ds-allow: skin color
        let b   = Color(red: 0.42, green: 0.72, blue: 1.00)  // ds-allow: skin color
        let pom = Color(red: 1.00, green: 0.86, blue: 0.36)  // ds-allow: skin color
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: s * 0.25, y: 0))
                p.addLine(to: CGPoint(x: 0, y: s * 0.32))
                p.addLine(to: CGPoint(x: s * 0.5, y: s * 0.32))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: s * 0.5, height: s * 0.32).offset(y: -s * 0.44)
            Circle().fill(pom).frame(width: s * 0.09, height: s * 0.09).offset(y: -s * 0.60)
        }
    }

    // Gravata — nó no pescoço + lâmina pendurada (formal / apresentação).
    private func tieView(_ s: CGFloat) -> some View {
        let tie = Color(red: 0.62, green: 0.18, blue: 0.24)  // ds-allow: skin color
        let dk  = Color(red: 0.44, green: 0.12, blue: 0.18)  // ds-allow: skin color
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.012).fill(dk)
                .frame(width: s * 0.08, height: s * 0.07).offset(y: s * 0.30)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: s * 0.09, y: 0))
                p.addLine(to: CGPoint(x: s * 0.045, y: s * 0.24))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [tie, dk], startPoint: .top, endPoint: .bottom))
            .frame(width: s * 0.09, height: s * 0.24).offset(y: s * 0.47)
        }
    }

    // Gorro de Natal — cone vermelho caído + faixa branca + pompom (sazonal).
    private func santaHatView(_ s: CGFloat) -> some View {
        let red   = Color(red: 0.82, green: 0.20, blue: 0.24)  // ds-allow: skin color
        let dk    = Color(red: 0.60, green: 0.13, blue: 0.17)  // ds-allow: skin color
        let white = Color(red: 0.97, green: 0.98, blue: 1.00)  // ds-allow: skin color
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: s * 0.5, y: 0))
                p.addLine(to: CGPoint(x: 0, y: s * 0.24))
                p.addLine(to: CGPoint(x: s * 0.42, y: s * 0.30))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [red, dk], startPoint: .top, endPoint: .bottom))
            .frame(width: s * 0.5, height: s * 0.30).offset(x: s * 0.04, y: -s * 0.44)
            Circle().fill(white).frame(width: s * 0.10, height: s * 0.10).offset(x: s * 0.28, y: -s * 0.56)
            Capsule().fill(white).frame(width: s * 0.52, height: s * 0.09).offset(y: -s * 0.30)
        }
    }

    // Chapéu de mago — aba + cone alto roxo + estrelinhas (ÉPICO, sabedoria).
    private func wizardHatView(_ s: CGFloat) -> some View {
        let hat  = Color(red: 0.34, green: 0.25, blue: 0.58)  // ds-allow: skin color
        let dk   = Color(red: 0.20, green: 0.14, blue: 0.38)  // ds-allow: skin color
        let star = Color(red: 1.00, green: 0.86, blue: 0.40)  // ds-allow: skin color
        return ZStack {
            Ellipse().fill(dk).frame(width: s * 0.72, height: s * 0.12).offset(y: -s * 0.26)
            Path { p in
                p.move(to: CGPoint(x: s * 0.25, y: 0))
                p.addLine(to: CGPoint(x: s * 0.02, y: s * 0.42))
                p.addLine(to: CGPoint(x: s * 0.48, y: s * 0.42))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [hat, dk], startPoint: .top, endPoint: .bottom))
            .frame(width: s * 0.5, height: s * 0.42).offset(y: -s * 0.54)
            Image(systemName: "star.fill").font(.system(size: s * 0.06)).foregroundColor(star)  // ds-allow: skin color
                .offset(x: s * 0.02, y: -s * 0.52)
            Image(systemName: "star.fill").font(.system(size: s * 0.04)).foregroundColor(star)  // ds-allow: skin color
                .offset(x: -s * 0.06, y: -s * 0.40)
        }
    }

    // Orelhas de gato — dois triângulos de pelo + interior rosa (fofo).
    private func catEarsView(_ s: CGFloat) -> some View {
        let fur   = Color(red: 0.30, green: 0.28, blue: 0.35)  // ds-allow: skin color
        let inner = Color(red: 0.92, green: 0.64, blue: 0.70)  // ds-allow: skin color
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { sign in
                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: s * 0.11, y: 0))
                        p.addLine(to: CGPoint(x: 0, y: s * 0.20))
                        p.addLine(to: CGPoint(x: s * 0.22, y: s * 0.20))
                        p.closeSubpath()
                    }
                    .fill(fur).frame(width: s * 0.22, height: s * 0.20)
                    Path { p in
                        p.move(to: CGPoint(x: s * 0.06, y: s * 0.05))
                        p.addLine(to: CGPoint(x: s * 0.02, y: s * 0.14))
                        p.addLine(to: CGPoint(x: s * 0.10, y: s * 0.14))
                        p.closeSubpath()
                    }
                    .fill(inner).frame(width: s * 0.12, height: s * 0.14)
                }
                .offset(x: CGFloat(sign) * s * 0.19, y: -s * 0.40)
            }
        }
    }

    // Bigode — duas metades curvas abaixo dos olhos (divertido).
    private func mustacheView(_ s: CGFloat) -> some View {
        let hair = Color(red: 0.26, green: 0.18, blue: 0.12)  // ds-allow: skin color
        return ZStack {
            Capsule().fill(hair).frame(width: s * 0.17, height: s * 0.06)
                .rotationEffect(.degrees(-14)).offset(x: -s * 0.08, y: s * 0.17)
            Capsule().fill(hair).frame(width: s * 0.17, height: s * 0.06)
                .rotationEffect(.degrees(14)).offset(x: s * 0.08, y: s * 0.17)
        }
    }

    // Tapa-olho — tira diagonal + tampão sobre um olho (pirata / pós-op).
    private func eyePatchView(_ s: CGFloat) -> some View {
        let patch = Color(red: 0.10, green: 0.11, blue: 0.14)  // ds-allow: skin color
        let strap = Color(red: 0.17, green: 0.18, blue: 0.22)  // ds-allow: skin color
        return ZStack {
            Capsule().fill(strap).frame(width: s * 0.74, height: s * 0.035)
                .rotationEffect(.degrees(-18)).offset(y: -s * 0.05)
            RoundedRectangle(cornerRadius: s * 0.03).fill(patch)
                .frame(width: s * 0.17, height: s * 0.19).offset(x: -s * 0.11, y: -s * 0.01)
        }
    }

    // Coroa de flores — vinha verde + flores DE VERDADE (5 pétalas + miolo). Rafael 2026-07-15.
    private func flowerCrownView(_ s: CGFloat) -> some View {
        let vine = Color(red: 0.36, green: 0.60, blue: 0.34)  // ds-allow: skin color
        let p1  = Color(red: 1.00, green: 0.55, blue: 0.68)   // ds-allow: skin color
        let p2  = Color(red: 0.72, green: 0.80, blue: 1.00)   // ds-allow: skin color
        let p3  = Color(red: 1.00, green: 0.80, blue: 0.42)   // ds-allow: skin color
        let mid = Color(red: 1.00, green: 0.86, blue: 0.34)   // ds-allow: skin color
        let cols = [p1, p2, p3, p1, p2]
        return ZStack {
            // vinha (arco verde por cima da cabeça)
            Circle().trim(from: 0.0, to: 0.5)
                .stroke(vine, style: StrokeStyle(lineWidth: s * 0.028, lineCap: .round))
                .rotationEffect(.degrees(180))
                .frame(width: s * 0.78, height: s * 0.78).offset(y: -s * 0.03)
            ForEach(0..<5, id: \.self) { i in
                let angle = (Double(i) / 4.0 - 0.5) * 128.0
                flowerBloom(cols[i], mid, s)
                    .offset(x: CGFloat(sin(angle * .pi / 180)) * s * 0.37,
                            y: -CGFloat(cos(angle * .pi / 180)) * s * 0.37)
            }
        }
    }

    // Uma flor: 5 pétalas (elipses radiando) + miolo.
    private func flowerBloom(_ petal: Color, _ mid: Color, _ s: CGFloat) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { k in
                Ellipse().fill(petal)
                    .frame(width: s * 0.048, height: s * 0.08)
                    .offset(y: -s * 0.035)
                    .rotationEffect(.degrees(Double(k) * 72))
            }
            Circle().fill(mid).frame(width: s * 0.05, height: s * 0.05)
        }
    }

    // Chifres de diabo — MAIORES, curvados pra fora (travesso). Rafael 2026-07-15.
    private func devilHornsView(_ s: CGFloat) -> some View {
        let red = Color(red: 0.84, green: 0.15, blue: 0.19)  // ds-allow: skin color
        let dk  = Color(red: 0.52, green: 0.08, blue: 0.12)  // ds-allow: skin color
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { sign in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: s * 0.28))                                   // base externa
                    p.addQuadCurve(to: CGPoint(x: s * 0.15, y: 0),                            // ponta (curva pra fora/cima)
                                   control: CGPoint(x: s * 0.02, y: s * 0.12))
                    p.addQuadCurve(to: CGPoint(x: s * 0.12, y: s * 0.28),                     // volta pela base interna
                                   control: CGPoint(x: s * 0.11, y: s * 0.14))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [red, dk], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.16, height: s * 0.28)
                .scaleEffect(x: CGFloat(sign), y: 1, anchor: .center)
                .offset(x: CGFloat(sign) * s * 0.20, y: -s * 0.40)
            }
        }
    }

    // Cartola — ASSENTA na cabeça (aba curva baixa + cilindro + leve inclinação).
    // Antes flutuava; agora abraça a curva do orb. Rafael 2026-07-15.
    private func topHatView(_ s: CGFloat) -> some View {
        let hat  = Color(red: 0.12, green: 0.12, blue: 0.16)  // ds-allow: skin color
        let top  = Color(red: 0.22, green: 0.22, blue: 0.27)  // ds-allow: skin color
        let band = Color(red: 0.62, green: 0.14, blue: 0.20)  // ds-allow: skin color
        return ZStack {
            // aba curva, LARGA e BAIXA (encaixa na coroa da cabeça)
            Ellipse().fill(hat).frame(width: s * 0.66, height: s * 0.14).offset(y: -s * 0.25)
                .overlay(Ellipse().fill(top.opacity(0.5)).frame(width: s * 0.5, height: s * 0.07).offset(y: -s * 0.27))
            // cilindro
            RoundedRectangle(cornerRadius: s * 0.02).fill(hat)
                .frame(width: s * 0.36, height: s * 0.27).offset(y: -s * 0.40)
            // faixa vermelha
            RoundedRectangle(cornerRadius: s * 0.008).fill(band)
                .frame(width: s * 0.36, height: s * 0.05).offset(y: -s * 0.31)
            // topo (elipse = tampa 3D)
            Ellipse().fill(top).frame(width: s * 0.36, height: s * 0.07).offset(y: -s * 0.535)
        }
        .rotationEffect(.degrees(-6))   // inclinação chique (colocada na cabeça, não flutuando)
    }

    // Nariz de palhaço — bolinha vermelha no centro do rosto (divertido).
    private func clownNoseView(_ s: CGFloat) -> some View {
        let lite = Color(red: 1.00, green: 0.50, blue: 0.50)  // ds-allow: skin color
        let red  = Color(red: 0.92, green: 0.18, blue: 0.20)  // ds-allow: skin color
        return Circle()
            .fill(RadialGradient(colors: [lite, red], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: s * 0.09))
            .frame(width: s * 0.14, height: s * 0.14)
            .offset(y: s * 0.11)
    }

    // Óculos de coração — lentes GRANDES (o olho do Vita é vertical → cobrir todo).
    // Rafael 2026-07-15: era pequeno demais no olho.
    private func heartGlassesView(_ s: CGFloat) -> some View {
        let lens = Color(red: 1.00, green: 0.35, blue: 0.55)  // ds-allow: skin color
        let rim  = Color(red: 0.86, green: 0.20, blue: 0.42)  // ds-allow: skin color
        return ZStack {
            Capsule().fill(rim).frame(width: s * 0.09, height: s * 0.025)
            ForEach([-1.0, 1.0], id: \.self) { sign in
                Image(systemName: "heart.fill")
                    .font(.system(size: s * 0.30))  // ds-allow: skin color
                    .foregroundColor(lens.opacity(0.9))
                    .overlay(Image(systemName: "heart").font(.system(size: s * 0.30)).foregroundColor(rim))  // ds-allow: skin color
                    .scaleEffect(x: 1, y: 1.12)
                    .offset(x: CGFloat(sign) * s * 0.15, y: 0)
            }
        }
    }

    // Corrente de ouro — elos ENVOLVENDO o pescoço (hugam a curva do orb), não na
    // "barriga". Pingente $ no centro. Rafael 2026-07-15.
    private func goldChainView(_ s: CGFloat) -> some View {
        let gold = Color(red: 1.00, green: 0.82, blue: 0.32)  // ds-allow: skin color
        let dk   = Color(red: 0.70, green: 0.50, blue: 0.14)  // ds-allow: skin color
        let r = s * 0.45
        return ZStack {
            // elos ao longo da curva INFERIOR do orb (colar em volta do pescoço)
            ForEach(0..<13, id: \.self) { i in
                let angle = (Double(i) / 12.0 - 0.5) * 136.0   // de -68° a +68° a partir de baixo
                Circle().fill(gold).frame(width: s * 0.05, height: s * 0.05)
                    .overlay(Circle().stroke(dk, lineWidth: s * 0.005))
                    .offset(x: CGFloat(sin(angle * .pi / 180)) * r,
                            y: CGFloat(cos(angle * .pi / 180)) * r)
            }
            // pingente $
            ZStack {
                Circle().fill(LinearGradient(colors: [gold, dk], startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.13, height: s * 0.13)
                    .overlay(Circle().stroke(dk, lineWidth: s * 0.006))
                Text("$").font(.system(size: s * 0.075, weight: .black)).foregroundColor(dk)  // ds-allow: skin color
            }
            .offset(y: r + s * 0.06)
        }
    }

    private func crownView(_ s: CGFloat) -> some View {
        let goldT = Color(red: 1.00, green: 0.87, blue: 0.55)   // ds-allow: skin color
        let goldM = Color(red: 0.86, green: 0.66, blue: 0.28)   // ds-allow: skin color
        let goldD = Color(red: 0.52, green: 0.37, blue: 0.12)   // ds-allow: skin color
        let gem   = Color(red: 0.86, green: 0.24, blue: 0.32)   // ds-allow: skin color
        return ZStack {
            CrownShape()
                .fill(LinearGradient(colors: [goldT, goldM, goldD], startPoint: .top, endPoint: .bottom))
                .overlay(CrownShape().stroke(goldD.opacity(0.7), lineWidth: s * 0.008))
                .frame(width: s * 0.66, height: s * 0.36)
                .offset(y: -s * 0.42)
            ForEach([-0.24, 0.0, 0.24], id: \.self) { fx in
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.9), gem],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: s * 0.035))
                    .frame(width: s * 0.07, height: s * 0.07)
                    .offset(x: CGFloat(fx) * s, y: -s * 0.45)
            }
            Capsule().fill(Color.white.opacity(0.55))
                .frame(width: s * 0.22, height: s * 0.02)
                .offset(x: -s * 0.10, y: -s * 0.30).blur(radius: 0.6)
        }
    }

    // Espelho frontal do médico — faixa CURVA na testa (segue o orb) + disco
    // côncavo metálico com furo e glint. Detalhe pra ler como PARTE do Vita.
    private func headMirrorView(_ s: CGFloat) -> some View {
        let strap   = Color(red: 0.13, green: 0.13, blue: 0.15)  // ds-allow: skin color
        let strapHi = Color(red: 0.34, green: 0.34, blue: 0.38)  // ds-allow: skin color
        let ringHi  = Color(red: 0.96, green: 0.98, blue: 1.00)  // ds-allow: skin color
        let ringMid = Color(red: 0.58, green: 0.64, blue: 0.74)  // ds-allow: skin color
        let ringLo  = Color(red: 0.24, green: 0.28, blue: 0.36)  // ds-allow: skin color
        return ZStack {
            // faixa curva na testa, brilho no topo + fio escuro embaixo (volume)
            HeadbandShape()
                .fill(LinearGradient(colors: [strapHi, strap], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.80, height: s * 0.20).offset(y: -s * 0.26)
            HeadbandShape()
                .stroke(Color.black.opacity(0.35), lineWidth: s * 0.008)
                .frame(width: s * 0.80, height: s * 0.20).offset(y: -s * 0.26)
            // haste montando o espelho na faixa
            Capsule().fill(strap)
                .frame(width: s * 0.035, height: s * 0.08).offset(x: -s * 0.02, y: -s * 0.22)
            // disco côncavo (metal): borda clara → centro fundo
            ZStack {
                Circle().fill(RadialGradient(colors: [ringLo, ringMid, ringHi],
                    center: UnitPoint(x: 0.5, y: 0.5), startRadius: s * 0.01, endRadius: s * 0.13))
                Circle().strokeBorder(
                    LinearGradient(colors: [ringHi, ringMid], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: s * 0.02)
                Circle().stroke(strap, lineWidth: s * 0.012)
                    .frame(width: s * 0.205, height: s * 0.205)
                Circle().fill(strap).frame(width: s * 0.045, height: s * 0.045)
                Ellipse().fill(Color.white.opacity(0.9))
                    .frame(width: s * 0.055, height: s * 0.028)
                    .rotationEffect(.degrees(-32))
                    .offset(x: -s * 0.05, y: -s * 0.05).blur(radius: 0.3)
            }
            .frame(width: s * 0.26, height: s * 0.26).offset(x: -s * 0.02, y: -s * 0.31)
        }
    }

    // Gorro de inverno — corpo de malha + barra dobrada + pompom. Luz de cima.
    private func beanieView(_ s: CGFloat) -> some View {
        let knit  = Color(red: 0.80, green: 0.30, blue: 0.32)   // ds-allow: skin color
        let knitD = Color(red: 0.58, green: 0.18, blue: 0.22)   // ds-allow: skin color
        let cuff  = Color(red: 0.92, green: 0.90, blue: 0.86)   // ds-allow: skin color
        return ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [knit, knitD], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.92, height: s * 0.62).offset(y: -s * 0.34)
            ForEach(-3...3, id: \.self) { i in
                Capsule().fill(Color.black.opacity(0.08))
                    .frame(width: s * 0.02, height: s * 0.34)
                    .offset(x: CGFloat(i) * s * 0.11, y: -s * 0.38)
            }
            Capsule().fill(LinearGradient(colors: [cuff, cuff.opacity(0.82)], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.90, height: s * 0.16).offset(y: -s * 0.16)
            Circle().fill(RadialGradient(colors: [cuff, cuff.opacity(0.7)],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: s * 0.09))
                .frame(width: s * 0.16, height: s * 0.16).offset(y: -s * 0.62)
        }
    }

    // Coroa de louros — dois ramos simétricos de folhas correndo por um arco em
    // volta da cabeça (de baixo-lado até quase o topo), tangentes à curva.
    private func laurelView(_ s: CGFloat) -> some View {
        let leaf  = Color(red: 0.58, green: 0.72, blue: 0.32)   // ds-allow: skin color
        let leafD = Color(red: 0.34, green: 0.48, blue: 0.17)   // ds-allow: skin color
        let berry = Color(red: 0.90, green: 0.76, blue: 0.32)   // ds-allow: skin color
        let R = s * 0.52
        let n = 9
        return ZStack {
            ForEach([1.0, -1.0], id: \.self) { sign in
                ForEach(0..<n, id: \.self) { i in
                    // arco denso de -30° (baixo-lado) → +86° (topo); folhas deitadas ao longo do arco
                    let t = Double(i) / Double(n - 1)
                    let deg = -30.0 + t * 116.0
                    let rad = deg * .pi / 180.0
                    let px = CGFloat(cos(rad)) * R
                    let py = -CGFloat(sin(rad)) * R
                    Ellipse()
                        .fill(LinearGradient(colors: [leaf, leafD], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: s * 0.155, height: s * 0.07)
                        .rotationEffect(.degrees(sign * (deg + 112)))
                        .offset(x: CGFloat(sign) * px, y: py)
                    if i % 3 == 1 {
                        Circle().fill(berry).frame(width: s * 0.034, height: s * 0.034)
                            .offset(x: CGFloat(sign) * px * 0.82, y: py * 0.82)
                    }
                }
            }
            // laço dourado na base
            Capsule().fill(berry.opacity(0.85))
                .frame(width: s * 0.10, height: s * 0.026).offset(y: s * 0.42)
        }
    }

    // Chapéu de capivara — cabecinha marrom com orelhas e focinho. Easter egg.
    private func capybaraHatView(_ s: CGFloat) -> some View {
        let fur  = Color(red: 0.55, green: 0.41, blue: 0.28)    // ds-allow: skin color
        let furD = Color(red: 0.40, green: 0.28, blue: 0.18)    // ds-allow: skin color
        let nose = Color(red: 0.26, green: 0.19, blue: 0.14)    // ds-allow: skin color
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { sign in
                Circle().fill(furD).frame(width: s * 0.14, height: s * 0.14)
                    .offset(x: CGFloat(sign) * s * 0.22, y: -s * 0.50)
            }
            Ellipse().fill(LinearGradient(colors: [fur, furD], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.60, height: s * 0.42).offset(y: -s * 0.40)
            Ellipse().fill(furD).frame(width: s * 0.34, height: s * 0.20).offset(y: -s * 0.30)
            ForEach([-1.0, 1.0], id: \.self) { sign in
                Circle().fill(nose).frame(width: s * 0.05, height: s * 0.05)
                    .offset(x: CGFloat(sign) * s * 0.12, y: -s * 0.45)
            }
            ForEach([-1.0, 1.0], id: \.self) { sign in
                Circle().fill(nose).frame(width: s * 0.03, height: s * 0.03)
                    .offset(x: CGFloat(sign) * s * 0.05, y: -s * 0.30)
            }
        }
    }

    // MARK: Rosto

    // Óculos de sol aviador — lentes escuras em gota, aro dourado, reflexo.
    private func sunglassesView(_ s: CGFloat) -> some View {
        let frame = Color(red: 0.82, green: 0.67, blue: 0.34)   // ds-allow: skin color
        let l1 = Color(red: 0.12, green: 0.14, blue: 0.20)      // ds-allow: skin color
        let l2 = Color(red: 0.02, green: 0.02, blue: 0.05)      // ds-allow: skin color
        let dx: CGFloat = s * 0.14
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { sign in
                ZStack {
                    Ellipse().fill(LinearGradient(colors: [l1, l2], startPoint: .top, endPoint: .bottom))
                    Ellipse().stroke(frame, lineWidth: s * 0.016)
                    Capsule().fill(Color.white.opacity(0.35))
                        .frame(width: s * 0.012, height: s * 0.09)
                        .rotationEffect(.degrees(-35)).offset(x: -s * 0.03, y: -s * 0.02)
                }
                .frame(width: s * 0.25, height: s * 0.21)
                .offset(x: CGFloat(sign) * dx, y: -s * 0.005)
            }
            Capsule().fill(frame).frame(width: dx * 0.6, height: s * 0.02).offset(y: -s * 0.05)
            Capsule().fill(frame).frame(width: s * 0.12, height: s * 0.016).offset(x: -(dx + s * 0.14), y: -s * 0.06)
            Capsule().fill(frame).frame(width: s * 0.12, height: s * 0.016).offset(x: dx + s * 0.14, y: -s * 0.06)
        }
    }

    // Máscara cirúrgica — cobre nariz→queixo (ABAIXO dos olhos, que ficam à mostra),
    // aramezinho do nariz no topo, pregas horizontais e alças subindo pras orelhas.
    private func surgicalMaskView(_ s: CGFloat) -> some View {
        let top  = Color(red: 0.50, green: 0.78, blue: 0.68)    // ds-allow: skin color
        let mid  = Color(red: 0.32, green: 0.58, blue: 0.50)    // ds-allow: skin color
        let wire = Color(red: 0.23, green: 0.45, blue: 0.39)    // ds-allow: skin color
        return ZStack {
            // alças finas subindo pras "orelhas" (laterais), atrás do corpo
            ForEach([-1.0, 1.0], id: \.self) { sign in
                Capsule().fill(mid)
                    .frame(width: s * 0.018, height: s * 0.24)
                    .rotationEffect(.degrees(Double(sign) * 20))
                    .offset(x: CGFloat(sign) * s * 0.27, y: s * 0.08)
            }
            // corpo cobrindo nariz→queixo
            MaskShape()
                .fill(LinearGradient(colors: [top, mid], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.56, height: s * 0.40).offset(y: s * 0.20)
            // aramezinho do nariz (borda de cima)
            Capsule().fill(wire).frame(width: s * 0.38, height: s * 0.02).offset(y: s * 0.03)
            // pregas
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(Color.black.opacity(0.08))
                    .frame(width: s * 0.46, height: s * 0.013)
                    .offset(y: s * 0.15 + CGFloat(i) * s * 0.07)
            }
        }
    }

    // Monóculo — 1 lente com aro dourado + correntinha pendurada. Nobre.
    private func monocleView(_ s: CGFloat) -> some View {
        let gold  = Color(red: 0.90, green: 0.74, blue: 0.38)   // ds-allow: skin color
        let goldD = Color(red: 0.58, green: 0.42, blue: 0.15)   // ds-allow: skin color
        let glass = Color(red: 0.64, green: 0.80, blue: 0.96).opacity(0.16)  // ds-allow: skin color
        return ZStack {
            Circle().fill(glass).frame(width: s * 0.26, height: s * 0.26)
            Circle().stroke(LinearGradient(colors: [gold, goldD], startPoint: .top, endPoint: .bottom),
                            lineWidth: s * 0.028)
                .frame(width: s * 0.26, height: s * 0.26)
            Capsule().fill(Color.white.opacity(0.6))
                .frame(width: s * 0.014, height: s * 0.07)
                .rotationEffect(.degrees(-30)).offset(x: -s * 0.055, y: -s * 0.05)
            // correntinha pendurada, mais nítida
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(goldD).frame(width: s * 0.022, height: s * 0.022)
                    .offset(x: s * 0.13 - CGFloat(i) * s * 0.012, y: s * 0.13 + CGFloat(i) * s * 0.055)
            }
        }
        .offset(x: s * 0.13, y: -s * 0.02)
    }

    // MARK: Pescoço / corpo

    // Estetoscópio — drapeja dos "ombros" descendo pela frente, com a peça de
    // auscultação (chrome, o herói) pendurada baixo. Lê como VESTIDO, não em U.
    private func stethoscopeView(_ s: CGFloat) -> some View {
        let tube  = Color(red: 0.20, green: 0.44, blue: 0.56)   // ds-allow: skin color
        let tubeD = Color(red: 0.12, green: 0.30, blue: 0.40)   // ds-allow: skin color
        let chr1  = Color(red: 0.93, green: 0.95, blue: 0.99)   // ds-allow: skin color
        let chr2  = Color(red: 0.46, green: 0.52, blue: 0.60)   // ds-allow: skin color
        return ZStack {
            StethDrapeShape()
                .stroke(LinearGradient(colors: [tube, tubeD], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))
                .frame(width: s * 0.74, height: s * 0.62).offset(y: s * 0.16)
            // diafragma metálico (herói)
            ZStack {
                Circle().fill(RadialGradient(colors: [chr1, chr2],
                    center: UnitPoint(x: 0.38, y: 0.30), startRadius: 0, endRadius: s * 0.11))
                Circle().strokeBorder(chr2, lineWidth: s * 0.016)
                Circle().stroke(tubeD, lineWidth: s * 0.01).frame(width: s * 0.13, height: s * 0.13)
                Ellipse().fill(Color.white.opacity(0.85))
                    .frame(width: s * 0.05, height: s * 0.025)
                    .offset(x: -s * 0.03, y: -s * 0.03).blur(radius: 0.3)
            }
            .frame(width: s * 0.19, height: s * 0.19).offset(x: s * 0.15, y: s * 0.47)
        }
    }

    // Jaleco — pano branco hugando a base do orb, gola em V aberta, ombros
    // PUXADOS PRA DENTRO (sem abas), bolso+caneta e "Dr. <nome>" bordado em cima
    // à direita. Simples de propósito (Rafael 2026-07-05: "não inventa moda").
    private func labCoatView(_ s: CGFloat) -> some View {
        let coat  = Color(red: 0.97, green: 0.98, blue: 1.00)  // ds-allow: skin color
        let shade = Color(red: 0.76, green: 0.81, blue: 0.88)  // ds-allow: skin color
        let line  = Color(red: 0.60, green: 0.66, blue: 0.74)  // ds-allow: skin color
        let pen   = Color(red: 0.20, green: 0.46, blue: 0.62)  // ds-allow: skin color
        let body = CoatBodyShape(shoulderY: 0.08, buttonY: 0.34)
        return ZStack {
            body.fill(LinearGradient(colors: [coat, shade], startPoint: .top, endPoint: .bottom))
                .frame(width: s, height: s).clipShape(Circle())
            body.stroke(line, lineWidth: s * 0.008)
                .frame(width: s, height: s).clipShape(Circle())
            // botões
            ForEach(0..<2, id: \.self) { i in
                Circle().fill(line)
                    .frame(width: s * 0.03, height: s * 0.03)
                    .offset(y: s * (0.35 + CGFloat(i) * 0.08))
            }
            // bolso + caneta (peito esq, sobre o branco)
            RoundedRectangle(cornerRadius: s * 0.012).stroke(line, lineWidth: s * 0.006)
                .frame(width: s * 0.13, height: s * 0.10).offset(x: -s * 0.17, y: s * 0.30)
            Capsule().fill(pen)
                .frame(width: s * 0.02, height: s * 0.085).offset(x: -s * 0.20, y: s * 0.27)
            // "Dr. <nome>" bordado — peito DIREITO, sobre o tecido branco
            if let nameTag, !nameTag.isEmpty {
                Text("Dr. \(nameTag)")
                    .font(.system(size: s * 0.04, weight: .semibold))  // ds-allow: bordado no jaleco (arte)
                    .foregroundColor(pen)
                    .offset(x: s * 0.18, y: s * 0.30)
            }
        }
        .frame(width: s, height: s)
    }

    // Gravata-borboleta — pequena e nítida, assentada no baixo-frente do orb.
    // Duas asas de seda com vinco + nó + brilho. Simples e limpa.
    private func bowTieView(_ s: CGFloat) -> some View {
        let silk  = Color(red: 0.82, green: 0.22, blue: 0.28)   // ds-allow: skin color
        let silkD = Color(red: 0.52, green: 0.12, blue: 0.18)   // ds-allow: skin color
        let collar  = Color(red: 0.96, green: 0.97, blue: 1.00) // ds-allow: skin color
        let collarS = Color(red: 0.74, green: 0.78, blue: 0.85) // ds-allow: skin color
        let y: CGFloat = s * 0.40
        return ZStack {
            // gola branca de camisa atrás (dá contexto — não flutua)
            ForEach([-1.0, 1.0], id: \.self) { sign in
                CollarWingShape()
                    .fill(LinearGradient(colors: [collar, collarS], startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.18, height: s * 0.16)
                    .scaleEffect(x: CGFloat(sign), y: 1)
                    .offset(x: CGFloat(sign) * s * 0.09, y: y + s * 0.02)
            }
            // asas da gravata
            ForEach([-1.0, 1.0], id: \.self) { sign in
                BowSideShape()
                    .fill(LinearGradient(colors: [silk, silkD], startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.19, height: s * 0.17)
                    .scaleEffect(x: CGFloat(sign), y: 1)
                    .offset(x: CGFloat(sign) * s * 0.10, y: y)
                BowSideShape().stroke(Color.black.opacity(0.14), lineWidth: s * 0.006)
                    .frame(width: s * 0.19, height: s * 0.17)
                    .scaleEffect(x: CGFloat(sign), y: 1)
                    .offset(x: CGFloat(sign) * s * 0.10, y: y)
            }
            RoundedRectangle(cornerRadius: s * 0.02)
                .fill(LinearGradient(colors: [silk, silkD], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.06, height: s * 0.12).offset(y: y)
            Capsule().fill(Color.white.opacity(0.3))
                .frame(width: s * 0.035, height: s * 0.014).offset(x: -s * 0.08, y: y - s * 0.03)
        }
    }

    // Cachecol — dá a volta na base (elipse) com ribbing de tricô + uma ponta
    // caindo na frente com franja. Abraça a esfera, não flutua.
    private func scarfView(_ s: CGFloat) -> some View {
        let wool  = Color(red: 0.80, green: 0.34, blue: 0.30)   // ds-allow: skin color
        let woolD = Color(red: 0.56, green: 0.21, blue: 0.19)   // ds-allow: skin color
        return ZStack {
            // volta em torno da base
            Ellipse().fill(LinearGradient(colors: [wool, woolD], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.84, height: s * 0.34).offset(y: s * 0.40)
            // ribbing de tricô seguindo a curva
            ForEach(-4...4, id: \.self) { i in
                Capsule().fill(Color.black.opacity(0.09))
                    .frame(width: s * 0.016, height: s * 0.18)
                    .rotationEffect(.degrees(Double(i) * 9))
                    .offset(x: CGFloat(i) * s * 0.085, y: s * 0.39)
            }
            // ponta caindo na frente
            RoundedRectangle(cornerRadius: s * 0.04)
                .fill(LinearGradient(colors: [wool, woolD], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.19, height: s * 0.34).offset(x: s * 0.12, y: s * 0.62)
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(Color.black.opacity(0.09))
                    .frame(width: s * 0.014, height: s * 0.28)
                    .offset(x: s * 0.12 + CGFloat(i - 1) * s * 0.05, y: s * 0.62)
            }
            // franja
            ForEach(0..<5, id: \.self) { i in
                Capsule().fill(woolD)
                    .frame(width: s * 0.02, height: s * 0.07)
                    .offset(x: s * 0.05 + CGFloat(i) * s * 0.035, y: s * 0.81)
            }
        }
    }

    // Medalha de ouro — fitas em V + medalhão com estrela. Campeão.
    private func goldMedalView(_ s: CGFloat) -> some View {
        let ribbon  = Color(red: 0.30, green: 0.42, blue: 0.72) // ds-allow: skin color
        let ribbonD = Color(red: 0.18, green: 0.28, blue: 0.52) // ds-allow: skin color
        let goldT = Color(red: 1.00, green: 0.87, blue: 0.52)   // ds-allow: skin color
        let goldM = Color(red: 0.84, green: 0.63, blue: 0.24)   // ds-allow: skin color
        let goldD = Color(red: 0.55, green: 0.40, blue: 0.14)   // ds-allow: skin color
        return ZStack {
            // fitas dos ombros convergindo pro medalhão (V em volta do pescoço)
            ForEach([-1.0, 1.0], id: \.self) { sign in
                Capsule().fill(LinearGradient(colors: [ribbon, ribbonD], startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.055, height: s * 0.34)
                    .rotationEffect(.degrees(Double(sign) * 20))
                    .offset(x: CGFloat(sign) * s * 0.10, y: s * 0.32)
            }
            // medalhão (rim + estrela + brilho especular)
            ZStack {
                Circle().fill(RadialGradient(colors: [goldT, goldM, goldD],
                    center: UnitPoint(x: 0.38, y: 0.30), startRadius: 0, endRadius: s * 0.12))
                Circle().strokeBorder(goldD, lineWidth: s * 0.014)
                Image(systemName: "star.fill")
                    .font(.system(size: s * 0.11)).foregroundColor(goldD.opacity(0.85))  // ds-allow: gravado (arte)
                Ellipse().fill(Color.white.opacity(0.5))
                    .frame(width: s * 0.06, height: s * 0.03).offset(x: -s * 0.04, y: -s * 0.04).blur(radius: 0.4)
            }
            .frame(width: s * 0.24, height: s * 0.24).offset(y: s * 0.50)
        }
    }

    private var orbGlow: some View {
        Circle()
            .fill(RadialGradient(
                colors: [primary.opacity(glowIntensity * 0.7), primary.opacity(glowIntensity * 0.15), .clear],
                center: .center, startRadius: size * 0.2, endRadius: size * 1.3
            ))
            .frame(width: size * 2.6, height: size * 2.6)
            .blur(radius: 22)
    }

    private var orbSparkles: some View {
        ForEach(0..<8, id: \.self) { i in
            Circle()
                .fill(bright.opacity(0.3 + sin(sparklePhase + Double(i) * 0.8) * 0.25))
                .frame(width: 1.5 + CGFloat(i % 3), height: 1.5 + CGFloat(i % 3))
                .offset(
                    x: cos(Double(i) * 0.7 + sparklePhase * 0.25) * size * 0.7,
                    y: sin(Double(i) * 0.5 + sparklePhase * 0.3) * size * 0.6
                )
                .blur(radius: 0.5)
        }
    }

    private var orbRing: some View {
        let ringGlow = Ellipse()
            .stroke(primary.opacity(0.12), lineWidth: 10)
            .frame(width: size * 1.45, height: size * 0.36)
            .blur(radius: 8)

        let ringMain = Ellipse()
            .stroke(
                AngularGradient(
                    colors: [primary.opacity(0.8), bright.opacity(0.5), primary.opacity(0.6), bright.opacity(0.12), primary.opacity(0.7)],
                    center: .center
                ),
                lineWidth: 1.8
            )
            .frame(width: size * 1.45, height: size * 0.36)
            .shadow(color: primary.opacity(0.5), radius: 10)

        return ZStack { ringGlow; ringMain }
            .rotationEffect(.degrees(-12 + sin(ringRotation * 0.3) * 2))
            .opacity(state == .sleeping ? 0.3 : (0.9 + pulseBoost * 0.1))
            .scaleEffect(1.0 + pulseBoost * 0.04)
            .shadow(color: primary.opacity(pulseBoost * 0.6), radius: 18 * pulseBoost)
    }

    // MARK: - Orb body — 3D sphere stack
    //
    // Layered like a render shader:
    //   1. base       — multi-stop radial body, deep terminator
    //   2. subsurface — palette-tinted inner glow on the lit side
    //   3. ambientFill— cool palette bounce on the bottom-back (atmospheric)
    //   4. terminator — extra darkening on the unlit side (occlusion)
    //   5. fresnelRim — bright crescent stroke on lit silhouette
    //   6. edgeGlow   — angular outer ring (the chrome/iris feel)
    //   7. specKey    — primary specular highlight (key light)
    //   8. specSecond — small wet sub-spec for that "polished glass" pop
    //   9. eyes
    private var orbBody: some View {
        ZStack {
            // ROTATES with the head — body parts and eyes are "attached"
            ZStack {
                orbBase
                orbSubsurface
                orbAmbientFill
                if animated { orbNebula }
                orbTerminator
                orbEyes
                orbCheeks
            }
            .rotationEffect(.degrees(headTilt))

            // STAYS FIXED — light source is environmental, doesn't rotate
            // with the orb. This is what reads as "real glass" instead of
            // "rotating sticker".
            orbFresnelRim
            orbEdgeGlow
            orbSpecKey
            orbSpecStreak
            orbSpecCaustic
        }
        .shadow(color: primary.opacity(state == .sleeping ? 0.08 : 0.30), radius: size * 0.22)
        .shadow(color: .black.opacity(0.6), radius: size * 0.12, y: size * 0.05)
    }

    private var orbBase: some View {
        // 4-stop radial: lit cap (palette tinted dark) → mid → terminator
        // → near-black palette-tinted edge. The body is now *made of* the
        // agent's color, not just lit by it.
        Circle()
            .fill(RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: palette.sphereInner,  location: 0.00),
                    .init(color: palette.sphereInner,  location: 0.30),
                    .init(color: palette.sphereMid,    location: 0.65),
                    .init(color: palette.sphereOuter,  location: 0.95),
                    .init(color: Color.black,          location: 1.00),
                ]),
                center: UnitPoint(x: 0.36, y: 0.30),
                startRadius: 0,
                endRadius: size * 0.62
            ))
            .frame(width: size, height: size)
    }

    private var orbSubsurface: some View {
        // Palette tint that "breathes" through the body on the lit cap —
        // gives the orb its chromatic identity (gold for Vita, teal for Pixio).
        Circle()
            .fill(RadialGradient(
                colors: [primary.opacity(state == .sleeping ? 0.05 : 0.22), .clear],
                center: UnitPoint(x: 0.36, y: 0.30),
                startRadius: 0,
                endRadius: size * 0.42
            ))
            .frame(width: size, height: size)
            .blendMode(.screen)
    }

    private var orbAmbientFill: some View {
        // Cool/colored bounce light from the bottom-back. Sells the volume.
        Circle()
            .fill(RadialGradient(
                colors: [primary.opacity(state == .sleeping ? 0.04 : 0.14), .clear],
                center: UnitPoint(x: 0.78, y: 0.86),
                startRadius: 0,
                endRadius: size * 0.55
            ))
            .frame(width: size, height: size)
            .blendMode(.screen)
    }

    private var orbTerminator: some View {
        // Extra darkening on the unlit side — strengthens 3D perception.
        // Stronger on the bottom-right than before so the silhouette pops.
        Circle()
            .fill(RadialGradient(
                colors: [
                    Color.black.opacity(0.85),
                    Color.black.opacity(0.55),
                    .clear,
                ],
                center: UnitPoint(x: 0.92, y: 0.82),
                startRadius: 0,
                endRadius: size * 0.55
            ))
            .frame(width: size, height: size)
            .blendMode(.multiply)
    }

    /// Clean fresnel rim — bright crescent on the lit silhouette. Stays
    /// FIXED relative to the world (light source doesn't rotate with the
    /// head), so it's rendered outside the headTilt rotation.
    private var orbFresnelRim: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [bright.opacity(0.85), primary.opacity(0.5), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: size * 0.018
            )
            .frame(width: size, height: size)
            .blur(radius: 0.5)
            .opacity(state == .sleeping ? 0.3 : 0.95)
    }

    private var orbEdgeGlow: some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [primary.opacity(0.6), bright.opacity(0.25), primary.opacity(0.45), dim.opacity(0.08), primary.opacity(0.55)],
                    center: .center
                ),
                lineWidth: 2.0
            )
            .frame(width: size, height: size)
            .shadow(color: primary.opacity(0.4), radius: 14)
    }

    private var orbSpecKey: some View {
        // Primary specular highlight — soft, large, the "key light" hot spot.
        Ellipse()
            .fill(RadialGradient(
                colors: [
                    Color.white.opacity(state == .sleeping ? 0.08 : 0.55),
                    Color.white.opacity(state == .sleeping ? 0.02 : 0.18),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.18
            ))
            .frame(width: size * 0.34, height: size * 0.22)
            .rotationEffect(.degrees(-22))
            .offset(x: -size * 0.20, y: -size * 0.26)
            .blur(radius: 1.2)
    }

    /// Vertical streak — what a *real* glass marble looks like under a window.
    /// Tall, soft-edged, slightly off-axis. NOT a dot. Reads as glass, not skin.
    private var orbSpecStreak: some View {
        ZStack {
            // Halo behind the streak
            Capsule()
                .fill(Color.white.opacity(state == .sleeping ? 0.05 : 0.30))
                .frame(width: size * 0.09, height: size * 0.34)
                .blur(radius: size * 0.04)
            // Bright core
            Capsule()
                .fill(LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(state == .sleeping ? 0.20 : 0.85),
                        Color.white.opacity(state == .sleeping ? 0.30 : 0.98),
                        Color.white.opacity(state == .sleeping ? 0.10 : 0.55),
                        Color.white.opacity(0.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: size * 0.045, height: size * 0.30)
                .blur(radius: 0.6)
            // Tiny sparkle pinpoint at the brightest spot
            Circle()
                .fill(Color.white.opacity(state == .sleeping ? 0.30 : 0.95))
                .frame(width: size * 0.022, height: size * 0.022)
                .offset(y: -size * 0.04)
                .blur(radius: 0.3)
        }
        .rotationEffect(.degrees(-12))
        .offset(x: -size * 0.21, y: -size * 0.18)
    }

    /// Caustic refraction spot — light entering the top exits as a bright
    /// crescent on the opposite (bottom-back) side. Tiny but it's the detail
    /// that says "thick glass" instead of "painted ball".
    private var orbSpecCaustic: some View {
        Ellipse()
            .fill(RadialGradient(
                colors: [
                    bright.opacity(state == .sleeping ? 0.08 : 0.55),
                    primary.opacity(state == .sleeping ? 0.04 : 0.20),
                    .clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.10
            ))
            .frame(width: size * 0.20, height: size * 0.10)
            .rotationEffect(.degrees(20))
            .offset(x: size * 0.18, y: size * 0.26)
            .blur(radius: 1.0)
    }

    /// Internal "nebula" — tiny particles drifting INSIDE the orb at a
    /// different velocity than the outer sparkles. Parallax = depth perception.
    /// Clipped to the orb circle so they look submerged in the body.
    private var orbNebula: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let baseAngle = Double(i) * (.pi * 2 / 6)
                let phase = sparklePhase * 0.4 + Double(i) * 0.5
                let r = size * (0.12 + 0.18 * Double((i % 3 + 1)) / 3)
                let alpha = 0.20 + 0.35 * (0.5 + 0.5 * sin(phase * 1.3 + Double(i)))
                let dotSize = size * (0.012 + 0.008 * Double(i % 3))
                Circle()
                    .fill(bright.opacity(state == .sleeping ? alpha * 0.2 : alpha))
                    .frame(width: dotSize, height: dotSize)
                    .offset(
                        x: cos(baseAngle + phase) * r,
                        y: sin(baseAngle + phase) * r * 0.85
                    )
                    .blur(radius: 0.4)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .blendMode(.screen)
    }

    private var orbEyes: some View {
        HStack(spacing: size * 0.17) {
            eyeView.rotationEffect(.degrees(eyeAngle))
            eyeView.rotationEffect(.degrees(-eyeAngle))
        }
        .offset(x: eyeLookX, y: -size * 0.02)
        // idleEnabled=false (LoginScreen pre-drag) → orb is "asleep, hidden",
        // eyes must be fully invisible. Smoothly fades back in as drag begins.
        .opacity(idleEnabled ? 1 : 0)
        .animation(.easeInOut(duration: 0.4), value: idleEnabled)
    }

    // Bochechas avermelhadas — Vita meio envergonhado por estar dormindo.
    // Acendem rapidamente quando ela acaba de acordar e diz "oiii". Usa
    // RadialGradient pra ficar suave, não dois círculos planos. Respeita
    // headTilt porque é parte do "rosto".
    private var orbCheeks: some View {
        HStack(spacing: size * 0.42) {
            cheekDot
            cheekDot
        }
        .offset(y: size * 0.10)
        .opacity(isBlushing ? 0.65 : 0)
        .animation(.easeInOut(duration: 0.45), value: isBlushing)
        .blendMode(.screen)
    }

    private var cheekDot: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.55, blue: 0.62).opacity(0.95),
                        Color(red: 1.0, green: 0.42, blue: 0.50).opacity(0.55),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: size * 0.13
                )
            )
            .frame(width: size * 0.22, height: size * 0.18)
            .blur(radius: 3)
    }

    private var eyeView: some View {
        // slowBlink = drowsy half-close (~40% of normal height for ~400ms)
        let baseH = slowBlink ? eyeHeight * 0.30 : eyeHeight
        let h = blinking ? size * 0.025 : baseH
        let w = blinking ? eyeWidth * 1.3 : eyeWidth
        return Group {
            if happyEyes && !blinking && state != .sleeping {
                // ^_^ — closed-arc smile eye. Triggered occasionally during
                // bounces. Reads as a burst of joy.
                HappyEyeArc()
                    .stroke(Color.white,
                            style: StrokeStyle(lineWidth: max(2.0, size * 0.022),
                                               lineCap: .round))
                    .frame(width: eyeWidth * 1.5, height: eyeHeight * 0.55)
                    .shadow(color: Color.white.opacity(0.6), radius: 8)
                    .shadow(color: Color.white.opacity(0.35), radius: 14)
            } else {
                // Plain white eyes — 3 halos + crisp white capsule.
                ZStack {
                    Capsule().fill(Color.white.opacity(state == .sleeping ? 0.04 : 0.20))
                        .frame(width: w + 8, height: h + 8).blur(radius: 8)
                    Capsule().fill(Color.white.opacity(state == .sleeping ? 0.08 : 0.40))
                        .frame(width: w + 4, height: h + 4).blur(radius: 4)
                    Capsule().fill(Color.white.opacity(state == .sleeping ? 0.40 : 0.95))
                        .frame(width: w, height: h)
                    if !blinking && state != .sleeping && h > size * 0.08 {
                        Capsule().fill(Color.white)
                            .frame(width: w * 0.5, height: h * 0.15)
                            .offset(y: -h * 0.3).opacity(0.4)
                    }
                }
                .shadow(color: Color.white.opacity(0.35), radius: 12)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: happyEyes)
        .animation(.easeInOut(duration: 0.08), value: blinking)
    }

    private var eyeWidth: CGFloat {
        switch state {
        case .sleeping: return size * 0.11
        case .waking:   return size * 0.075
        case .awake:    return size * 0.075
        case .thinking: return size * 0.07
        case .happy:    return size * 0.085
        }
    }

    private var eyeHeight: CGFloat {
        switch state {
        case .sleeping: return size * 0.025
        case .waking:   return size * 0.13
        case .awake:    return size * 0.22
        case .thinking: return size * 0.16
        case .happy:    return size * 0.18
        }
    }

    // MARK: - Animations
    private func startAnimations() {
        // Thumbnail estático (galeria/provador) — ZERO animação em loop pra não
        // afundar o FPS quando há dezenas de orbs na tela. Prototype 2026-07-05.
        guard animated else {
            glowIntensity = state == .sleeping ? 0.2 : 0.5
            return
        }
        // Subtle background rotations + glow always on (sells "alive" even when idle off).
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            glowIntensity = state == .sleeping ? 0.2 : 0.55
        }
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { sparklePhase = .pi * 2 }
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { ringRotation = .pi * 2 }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { auraHue = 1.0 }

        // Idle motion — only when idleEnabled (LoginScreen passes false to "freeze" the orb).
        if idleEnabled {
            if bob {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) { floatY = -8 }
            }
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { breathScale = 1.025 }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) { eyeAngle = 5 }
        }

        loopTask?.cancel()
        loopTask = Task { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                guard self.idleEnabled else { return }
                group.addTask { await self.eyeLookLoop() }
                group.addTask { await self.blinkLoop() }
                if self.bounceEnabled {
                    group.addTask { await self.bounceLoop() }
                }
                group.addTask { await self.headTiltLoop() }
                group.addTask { await self.idleDriftLoop() }
                group.addTask { await self.magicPulseLoop() }
                group.addTask { await self.slowBlinkLoop() }
            }
        }
    }

    // MARK: - New behavior loops

    /// Curious head tilt — orb rotates a few degrees, holds, returns. Sometimes
    /// pairs with the eye look so it really feels like it's *looking* at
    /// something off-screen.
    @MainActor
    private func headTiltLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 3500...7000)))
            guard !Task.isCancelled else { break }
            let tilt = Double.random(in: 4...8) * (Bool.random() ? 1 : -1)
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                headTilt = tilt
                eyeLookX = CGFloat(tilt > 0 ? -1 : 1) * size * 0.035
            }
            try? await Task.sleep(for: .milliseconds(Int.random(in: 900...1800)))
            guard !Task.isCancelled else { break }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                headTilt = 0
                eyeLookX = 0
            }
        }
    }

    /// Idle micro-drift so the orb is never *perfectly* still — sells "alive".
    @MainActor
    private func idleDriftLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 2200...4500)))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 1.6)) {
                idleDriftX = CGFloat.random(in: -size * 0.025...size * 0.025)
            }
        }
    }

    /// Magic pulse — every 6-12s the ring brightens and a spark wave goes out.
    /// Visualizes the orb "thinking of something". Hookable for chat states.
    @MainActor
    private func magicPulseLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 6000...12000)))
            guard !Task.isCancelled else { break }
            withAnimation(.easeOut(duration: 0.5)) { pulseBoost = 1.0 }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { break }
            withAnimation(.easeIn(duration: 1.2)) { pulseBoost = 0.0 }
        }
    }

    /// Sleepy slow-blink — occasional drowsy half-close that lingers.
    /// Different rhythm than the regular blink so it reads as a separate "mood"
    /// rather than just a long blink.
    @MainActor
    private func slowBlinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 9000...18000)))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 0.25)) { slowBlink = true }
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 0.30)) { slowBlink = false }
        }
    }

    private func triggerBounce() {
        // ~40% of bounces also trigger happy ^_^ eyes for the duration of
        // the hop. Random so it doesn't feel mechanical.
        let goHappy = Double.random(in: 0...1) < 0.40
        Task { @MainActor in
            withAnimation(.easeIn(duration: 0.1)) { squishY = 0.85; squishX = 1.12 }
            if goHappy { happyEyes = true }
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                bounceY = -25; squishY = 1.1; squishX = 0.92
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                bounceY = 0; squishY = 0.9; squishX = 1.08
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                squishY = 1.0; squishX = 1.0
            }
            // Hold the happy face a beat after landing, then drop it
            if goHappy {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                happyEyes = false
            }
        }
    }

    @MainActor
    private func bounceLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 4000...8000)))
            guard !Task.isCancelled else { break }
            triggerBounce()
        }
    }

    @MainActor
    private func eyeLookLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 1500...3500)))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 0.5)) {
                eyeLookX = CGFloat.random(in: -size * 0.04...size * 0.04)
            }
            try? await Task.sleep(for: .milliseconds(Int.random(in: 800...2000)))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 0.4)) { eyeLookX = 0 }
        }
    }

    @MainActor
    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 2500...5000)))
            guard !Task.isCancelled else { break }
            blinking = true
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { break }
            blinking = false
        }
    }
}

// MARK: - State (shared with legacy VitaMascot callsites)

enum VitaMascotState: Equatable {
    case sleeping, waking, awake, thinking, happy
}

// MARK: - Backwards-compat alias
//
// Older callsites still pass `VitaMascot(state:size:)`. Routes to OrbMascot
// with the gold palette. (showStaff arg accepted but ignored — staff was
// retired 2026-04-18.)

struct VitaMascot: View {
    var state: VitaMascotState = .awake
    var size: CGFloat = 120
    var showStaff: Bool = false
    var idleEnabled: Bool = true
    var isBlushing: Bool = false

    var body: some View {
        OrbMascot(
            palette: .vita,
            state: state,
            size: size,
            idleEnabled: idleEnabled,
            isBlushing: isBlushing
        )
    }
}

// MARK: - Shapes

/// ^_^ — closed-arc happy eye. Upward-curving smile-eye, like anime joy.
private struct HappyEyeArc: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.5)
            )
        }
    }
}

// MARK: - Skin shapes

/// Coroa de 5 pontas com aro na base. Pontas externas mais baixas, centro alto.
private struct CrownShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        let baseY = r.minY + h * 0.70
        let pts: [CGFloat]    = [0.08, 0.29, 0.50, 0.71, 0.92]   // x das pontas
        let peakY: [CGFloat]  = [0.20, 0.04, 0.00, 0.04, 0.20]   // altura (0 = mais alto)
        let valleys: [CGFloat] = [0.185, 0.395, 0.605, 0.815]    // vales entre pontas
        return Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: baseY))
            for i in 0..<pts.count {
                p.addLine(to: CGPoint(x: r.minX + w * pts[i], y: r.minY + h * peakY[i]))
                if i < valleys.count {
                    p.addLine(to: CGPoint(x: r.minX + w * valleys[i], y: baseY))
                }
            }
            p.addLine(to: CGPoint(x: r.maxX, y: baseY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

/// Estetoscópio drapejado — dois tubos descendo dos "ombros" pela frente; o da
/// direita termina no diafragma (baixo-direita).
private struct StethDrapeShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        return Path { p in
            p.move(to: CGPoint(x: r.minX + w * 0.08, y: r.minY))
            p.addCurve(to: CGPoint(x: r.minX + w * 0.44, y: r.minY + h * 0.80),
                       control1: CGPoint(x: r.minX + w * 0.02, y: r.minY + h * 0.48),
                       control2: CGPoint(x: r.minX + w * 0.26, y: r.minY + h * 0.74))
            p.move(to: CGPoint(x: r.minX + w * 0.92, y: r.minY))
            p.addCurve(to: CGPoint(x: r.minX + w * 0.70, y: r.minY + h * 0.98),
                       control1: CGPoint(x: r.minX + w * 0.99, y: r.minY + h * 0.52),
                       control2: CGPoint(x: r.minX + w * 0.86, y: r.minY + h * 0.86))
        }
    }
}

/// Calota da cabeça acima de `browY`: topo bufando um pouco além da esfera, borda
/// inferior curvando pra baixo no meio (hug da testa). Base segue a silhueta real.
private struct SphereCapShape: Shape {
    var browY: CGFloat
    func path(in r: CGRect) -> Path {
        let w = r.width
        let cx = r.midX, cy = r.midY
        let rad = 0.5 * w
        let by = cy + browY * w
        let hw = (0.25 - browY * browY).squareRoot() * w
        return Path { p in
            p.move(to: CGPoint(x: cx - hw, y: by))
            p.addCurve(to: CGPoint(x: cx + hw, y: by),
                       control1: CGPoint(x: cx - rad * 0.86, y: cy - rad * 1.54),
                       control2: CGPoint(x: cx + rad * 0.86, y: cy - rad * 1.54))
            p.addQuadCurve(to: CGPoint(x: cx - hw, y: by),
                           control: CGPoint(x: cx, y: by + 0.12 * w))
            p.closeSubpath()
        }
    }
}

/// Corpo do jaleco — cobre o "peito/ombros" (base do orb) com ombros
/// ARREDONDADOS e gola em V suave. Clipar a um Circle() faz abraçar o orb.
private struct CoatBodyShape: Shape {
    var shoulderY: CGFloat
    var buttonY: CGFloat
    func path(in r: CGRect) -> Path {
        let w = r.width
        let cx = r.midX, cy = r.midY
        let rad = 0.5 * w
        let sy = cy + shoulderY * w
        let by = cy + buttonY * w
        let hw = (0.25 - shoulderY * shoulderY).squareRoot() * 0.98 * w  // cheio, clipado ao orb (sem abas p/ fora)
        return Path { p in
            p.move(to: CGPoint(x: cx - hw, y: sy))
            p.addCurve(to: CGPoint(x: cx, y: cy + rad * 0.99),
                       control1: CGPoint(x: cx - rad * 1.00, y: cy + rad * 0.58),
                       control2: CGPoint(x: cx - rad * 0.55, y: cy + rad * 0.99))
            p.addCurve(to: CGPoint(x: cx + hw, y: sy),
                       control1: CGPoint(x: cx + rad * 0.55, y: cy + rad * 0.99),
                       control2: CGPoint(x: cx + rad * 1.00, y: cy + rad * 0.58))
            p.addQuadCurve(to: CGPoint(x: cx, y: by),
                           control: CGPoint(x: cx + hw * 0.42, y: sy + (by - sy) * 0.12))
            p.addQuadCurve(to: CGPoint(x: cx - hw, y: sy),
                           control: CGPoint(x: cx - hw * 0.42, y: sy + (by - sy) * 0.12))
            p.closeSubpath()
        }
    }
}

/// Touca bufante — estufa pra FORA (mais larga que a cabeça) e é presa por um
/// elástico franzido em `browY`. Estreita no elástico, larga acima (muffin).
private struct BouffantShape: Shape {
    var browY: CGFloat
    func path(in r: CGRect) -> Path {
        let w = r.width
        let cx = r.midX, cy = r.midY
        let rad = 0.5 * w
        let by = cy + browY * w
        let hwBand = (0.25 - browY * browY).squareRoot() * w
        return Path { p in
            p.move(to: CGPoint(x: cx - hwBand, y: by))
            p.addCurve(to: CGPoint(x: cx, y: cy - rad * 1.34),
                       control1: CGPoint(x: cx - rad * 1.30, y: by - rad * 0.32),
                       control2: CGPoint(x: cx - rad * 0.80, y: cy - rad * 1.34))
            p.addCurve(to: CGPoint(x: cx + hwBand, y: by),
                       control1: CGPoint(x: cx + rad * 0.80, y: cy - rad * 1.34),
                       control2: CGPoint(x: cx + rad * 1.30, y: by - rad * 0.32))
            p.addQuadCurve(to: CGPoint(x: cx - hwBand, y: by),
                           control: CGPoint(x: cx, y: by + 0.10 * w))
            p.closeSubpath()
        }
    }
}

/// Banda fina seguindo a esfera na latitude `y` — as duas bordas curvam pra baixo
/// no meio (frente da bola). Deixa golas/bandas/cachecol "abraçarem" o orb.
private struct SphereBandArc: Shape {
    var y: CGFloat
    var thickness: CGFloat
    func path(in r: CGRect) -> Path {
        let w = r.width
        let cx = r.midX, cy = r.midY
        let yy = cy + y * w
        let hw = (0.25 - y * y).squareRoot() * w
        let dip = 0.09 * w
        let th = thickness * w
        return Path { p in
            p.move(to: CGPoint(x: cx - hw, y: yy))
            p.addQuadCurve(to: CGPoint(x: cx + hw, y: yy),
                           control: CGPoint(x: cx, y: yy + dip))
            p.addLine(to: CGPoint(x: cx + hw, y: yy + th))
            p.addQuadCurve(to: CGPoint(x: cx - hw, y: yy + th),
                           control: CGPoint(x: cx, y: yy + dip + th))
            p.closeSubpath()
        }
    }
}

/// Faixa da testa — banda que arqueia pra cima no meio (segue a curva do orb).
private struct HeadbandShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        return Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY + h * 0.55))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.55),
                           control: CGPoint(x: r.midX, y: r.minY - h * 0.15))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY),
                           control: CGPoint(x: r.midX, y: r.minY + h * 0.45))
            p.closeSubpath()
        }
    }
}

/// Máscara cirúrgica — trapézio arredondado: largo em cima (nariz), estreita no queixo.
private struct MaskShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        return Path { p in
            p.move(to: CGPoint(x: r.minX + w * 0.04, y: r.minY + h * 0.06))
            p.addQuadCurve(to: CGPoint(x: r.maxX - w * 0.04, y: r.minY + h * 0.06),
                           control: CGPoint(x: r.midX, y: r.minY - h * 0.06))
            p.addLine(to: CGPoint(x: r.maxX - w * 0.20, y: r.maxY - h * 0.05))
            p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.20, y: r.maxY - h * 0.05),
                           control: CGPoint(x: r.midX, y: r.maxY + h * 0.10))
            p.closeSubpath()
        }
    }
}

/// Aba de gola de camisa (ponta pra baixo-centro). Espelha por scaleEffect.
private struct CollarWingShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        return Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + h * 0.15))
            p.addLine(to: CGPoint(x: r.minX + w * 0.35, y: r.maxY))
            p.closeSubpath()
        }
    }
}

/// Asa da gravata-borboleta — pinça no lado interno, larga no externo.
private struct BowSideShape: Shape {
    func path(in r: CGRect) -> Path {
        return Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.closeSubpath()
        }
    }
}
