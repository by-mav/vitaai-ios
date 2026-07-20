import SwiftUI

// MARK: - TrailWorld — paleta do MUNDO da trilha (Home), tokenizada.
//
// 2026-07-03 (go goldstandard, Rafael): o mapa-jogo era um mundo DIURNO verde
// Duolingo — outro universo visual dentro do app Frosted Gold. Este arquivo o
// re-ambienta como o "campo do Vita à noite": campo úmbrio quente sob luz
// dourada, estrada de OURO, vaga-lumes no lugar das flores, prédios de pedra
// com janelas ACESAS. A mecânica (trilha/nós/tiers/mascote) não muda — só a
// luz. Tons de joia por tier mantêm a legibilidade de progressão do jogo.
//
// FONTE ÚNICA das cores do mundo: HomeScreen (e o dock da Home) consomem
// daqui. Mudar o clima do mundo inteiro = mudar este arquivo.

enum TrailWorld {

    // MARK: Campo noturno (fundo)
    static let fieldTop     = Color(red: 0.106, green: 0.086, blue: 0.051) // úmbrio quente
    static let fieldBottom  = Color(red: 0.055, green: 0.043, blue: 0.027)
    static let meadowTop    = Color(red: 0.125, green: 0.102, blue: 0.060) // canvas do campo
    static let meadowBottom = Color(red: 0.071, green: 0.055, blue: 0.033)

    // Tufos de capim (textura sutil, baixo contraste — noite)
    static let tuftDeep  = Color(red: 0.19, green: 0.15, blue: 0.086)
    static let tuftMid   = Color(red: 0.25, green: 0.20, blue: 0.11)
    static let tuftLight = Color(red: 0.34, green: 0.28, blue: 0.15)

    // Vaga-lumes (eram florzinhas amarela/rosa no mundo diurno)
    static let fireflyGold = Color(red: 1.0, green: 0.84, blue: 0.42)
    static let fireflyWarm = Color(red: 1.0, green: 0.93, blue: 0.72)

    // Árvores (silhueta bronze-oliva + tronco)
    static let canopyDeep  = Color(red: 0.13, green: 0.11, blue: 0.055)
    static let canopyMid   = Color(red: 0.19, green: 0.16, blue: 0.08)
    static let canopyLight = Color(red: 0.27, green: 0.23, blue: 0.115)
    static let trunkTop    = Color(red: 0.35, green: 0.22, blue: 0.11)
    static let trunkBottom = Color(red: 0.20, green: 0.12, blue: 0.05)

    // MARK: Estrada de ouro (era terra batida)
    static let roadEdge    = Color(red: 0.45, green: 0.32, blue: 0.14)
    static let roadSurface = Color(red: 0.78, green: 0.60, blue: 0.30)

    // MARK: Construções à noite — pedra quente + janelas acesas.
    // No mundo diurno cada prédio tinha sua cor pastel (creme/menta/teal/lilás);
    // à noite todos convergem pra MESMA família de pedra sob luz dourada — a
    // identidade de cada um fica no acento (cruz vermelha acesa, bandeira, selo).
    static let stoneTop    = Color(red: 0.33, green: 0.27, blue: 0.19)
    static let stoneBottom = Color(red: 0.20, green: 0.16, blue: 0.11)
    static let stoneWing   = Color(red: 0.24, green: 0.20, blue: 0.14)
    static let roofTop     = Color(red: 0.42, green: 0.30, blue: 0.16)
    static let roofBottom  = Color(red: 0.26, green: 0.17, blue: 0.09)
    static let windowGlow  = Color(red: 1.0, green: 0.80, blue: 0.42)   // aceso
    static let windowDim   = Color(red: 0.85, green: 0.64, blue: 0.32)
    static let wood        = Color(red: 0.30, green: 0.21, blue: 0.12)  // porta/base/mastro
    static let crossRed    = Color(red: 0.90, green: 0.26, blue: 0.26)  // cruz de plantão acesa
    static let signTint    = Color(red: 0.55, green: 0.42, blue: 0.20)  // glifo nos selos brancos
    static let flag        = Color(red: 1.0, green: 0.78, blue: 0.35)
    static let vanShade    = Color(red: 0.72, green: 0.66, blue: 0.54)  // sombra do corpo da ambulância
    static let wheel       = Color(red: 0.10, green: 0.09, blue: 0.07)
    static let vialGreen   = Color(red: 0.42, green: 0.80, blue: 0.58)  // luzinhas do lab
    static let vialAmber   = Color(red: 0.98, green: 0.78, blue: 0.35)
    static let vialBlue    = Color(red: 0.55, green: 0.68, blue: 0.98)

    // MARK: Tiers — tons de JOIA (mantêm o hue de progressão, afinados pra noite)
    // 0 Calouro=Ouro · 1 Acadêmico=Esmeralda · 2 Interno=Safira ·
    // 3 Residente=Ametista · 4 Médico=Rubi
    static let tier0Bright = Color(red: 0.97, green: 0.78, blue: 0.42)
    static let tier0Mid    = Color(red: 0.80, green: 0.58, blue: 0.28)
    static let tier0Dark   = Color(red: 0.36, green: 0.24, blue: 0.10)
    static let tier1Bright = Color(red: 0.44, green: 0.84, blue: 0.60)
    static let tier1Mid    = Color(red: 0.16, green: 0.56, blue: 0.38)
    static let tier1Dark   = Color(red: 0.05, green: 0.22, blue: 0.15)
    static let tier2Bright = Color(red: 0.50, green: 0.72, blue: 1.0)
    static let tier2Mid    = Color(red: 0.22, green: 0.46, blue: 0.84)
    static let tier2Dark   = Color(red: 0.06, green: 0.17, blue: 0.40)
    static let tier3Bright = Color(red: 0.76, green: 0.60, blue: 1.0)
    static let tier3Mid    = Color(red: 0.52, green: 0.36, blue: 0.84)
    static let tier3Dark   = Color(red: 0.22, green: 0.13, blue: 0.44)
    static let tier4Bright = Color(red: 1.0, green: 0.70, blue: 0.46)
    static let tier4Mid    = Color(red: 0.84, green: 0.34, blue: 0.30)
    static let tier4Dark   = Color(red: 0.40, green: 0.10, blue: 0.13)

    // MARK: Muralha de seção (sebe + pilares de pedra com lampiões acesos)
    static let hedgeTop    = Color(red: 0.20, green: 0.175, blue: 0.09)
    static let hedgeBottom = Color(red: 0.10, green: 0.088, blue: 0.045)
    static let hedgeBump   = Color(red: 0.245, green: 0.215, blue: 0.115)

    // MARK: Bichinhos do mundo (silhueta noturna + variante dourada rara)
    static let critterBody  = Color(red: 0.17, green: 0.13, blue: 0.075)
    static let critterBelly = Color(red: 0.245, green: 0.195, blue: 0.115)

    // MARK: Chrome da Home (dock de ferramentas flutuante)
    static let dockFill = Color(red: 0.10, green: 0.085, blue: 0.06)
}
