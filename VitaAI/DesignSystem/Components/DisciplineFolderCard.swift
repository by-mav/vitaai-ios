import SwiftUI

// MARK: - DisciplineFolderCard
//
// Pasta 3D no dialeto Frosted Gold (unificação 2026-07-03): corpo ESCURO
// premium (tokens Dark), papéis creme saindo, e a COR da disciplina vive SÓ
// na ABA (acento funcional pra distinguir matérias) — o corpo inteiramente
// colorido brigava com a paleta monocromática-ouro do app (Rafael).
// Structure (back to front):
//   1. Back panel — dark elevado, com a aba na cor da disciplina
//   2. Inner documents — 2-3 sheets creme com hints de conteúdo
//   3. Front panel — dark, nome + estrela dourada + vitaScore
//
// Designed for 3-column LazyVGrid. Name is ON the folder, not below.

struct DisciplineFolderCard: View {
    let subjectName: String
    var itemCount: Int = 0
    var onMenu: (() -> Void)?

    @State private var starred = false

    private var color: Color { SubjectColors.colorFor(subject: subjectName) }

    private var shortName: String {
        subjectName
            .replacingOccurrences(of: "(?i),.*$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)\\bMÉDICA\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)\\bMÉDICO\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\b(III|II|I)\\b", with: "", options: .regularExpression)
            .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    // Nome curto e bonito pra pastinha (SaaS): abrevia conhecidos, trunca o resto
    // no limite de palavra. MEDICINA LEGAL -> MED. LEGAL, familia e comunidade ->
    // MFC, praticas... -> PRATICAS, longo -> "SOCIEDADE E…".
    // Nome curto e bonito pra pastinha (SaaS): abrevia conhecidos, trunca o
    // resto no limite de palavra. MEDICINA LEGAL -> MED. LEGAL, familia e
    // comunidade -> MFC, praticas... -> PRATICAS, longo -> "SOCIEDADE E…".
    // Nome pra pastinha (SaaS, ZERO abreviacao por-disciplina): so limite de
    // caracteres pro olho humano. FARMACOLOGIA (12) cabe; longos cortam com "…"
    // (ex: PRATICAS INTER…, SOCIEDADE E…). Serve pra qualquer disciplina.
    static func folderLabel(_ raw: String) -> String {
        // limpeza generica: uppercase, corta apos virgula, tira MEDICA/MEDICO
        // e romanos finais (nivel do curso). Nada especifico de materia.
        var s = raw.uppercased().components(separatedBy: ",").first ?? raw.uppercased()
        let noise: Set<String> = ["MÉDICA", "MÉDICO", "MEDICA", "MEDICO", "I", "II", "III", "IV", "V"]
        s = s.split(separator: " ").map(String.init)
            .filter { !noise.contains($0) }
            .joined(separator: " ")
        let maxChars = 15
        if s.count <= maxChars { return s }
        var cut = String(s.prefix(maxChars - 1)).trimmingCharacters(in: .whitespaces)
        if let sp = cut.lastIndex(of: " ") {
            let lastWord = cut[cut.index(after: sp)...]
            if lastWord.count < 3 {
                cut = String(cut[..<sp]).trimmingCharacters(in: .whitespaces)
            }
        }
        return cut + "…"
    }

    var body: some View {
        folderIcon
            .frame(height: 88)
            .onAppear { starred = Self.isFavorite(subjectName) }
    }

    // MARK: - The folder icon

    private var folderIcon: some View {
        // Corpo escuro (tokens Dark, luz de cima: topo mais claro que a base);
        // a cor da disciplina fica só na aba + glow sutil da sombra.
        let backTop  = VitaTokens.DarkColors.bgActive
        let backBot  = VitaTokens.DarkColors.bgElevated
        let main     = VitaTokens.DarkColors.bgHover
        let darker   = VitaTokens.DarkColors.bgCard

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // ── Layer 1: Back panel (dark, behind documents)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [backTop, backBot],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w - 4, height: h * 0.78)
                    .offset(y: -h * 0.02)

                // ── Layer 2: Documents peeking out (just tips above front panel)
                documentSheets(width: w, height: h)

                // ── Layer 3: Front panel (solid, with name)
                frontPanel(width: w, height: h, mainColor: main, darkColor: darker)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 4)
        .shadow(color: color.opacity(0.10), radius: 2, x: 0, y: 1)
    }

    // MARK: - Documents peeking out (just tips, shifted right, with content)

    private func documentSheets(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            // Sheet 1 — left-center, "text document"
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(white: 0.95))
                .overlay { RoundedRectangle(cornerRadius: 2.5).fill(color.opacity(0.34)) }  // folha na cor da disciplina
                .frame(width: w * 0.28, height: h * 0.34)
                .overlay(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1.5) {
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color(white: 0.78))
                            .frame(width: w * 0.18, height: 1.2)
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color(white: 0.82))
                            .frame(width: w * 0.14, height: 1.2)
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color(white: 0.80))
                            .frame(width: w * 0.16, height: 1.2)
                    }
                    .padding(.top, 3)
                    .padding(.leading, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .rotationEffect(.degrees(-2), anchor: .bottom)
                .offset(x: w * 0.0, y: -h * 0.14)
                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)

            // Sheet 2 — center-right, "image document"
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(white: 0.96))
                .overlay { RoundedRectangle(cornerRadius: 2.5).fill(color.opacity(0.26)) }  // folha na cor da disciplina
                .frame(width: w * 0.26, height: h * 0.38)
                .overlay(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.15), color.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.16, height: h * 0.08)
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color(white: 0.80))
                            .frame(width: w * 0.15, height: 1.2)
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color(white: 0.84))
                            .frame(width: w * 0.11, height: 1.2)
                    }
                    .padding(.top, 3)
                    .padding(.leading, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .offset(x: w * 0.12, y: -h * 0.18)
                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)

            // Sheet 3 — far right, "chart" feel
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(white: 0.94))
                .overlay { RoundedRectangle(cornerRadius: 2.5).fill(color.opacity(0.40)) }  // folha na cor da disciplina
                .frame(width: w * 0.22, height: h * 0.30)
                .overlay(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1.5) {
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color(white: 0.76))
                            .frame(width: w * 0.14, height: 1.2)
                        HStack(spacing: 1) {
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(color.opacity(0.20))
                                .frame(width: 2, height: 4)
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(color.opacity(0.16))
                                .frame(width: 2, height: 6)
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(color.opacity(0.22))
                                .frame(width: 2, height: 3)
                        }
                    }
                    .padding(.top, 3)
                    .padding(.leading, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .rotationEffect(.degrees(3), anchor: .bottom)
                .offset(x: w * 0.22, y: -h * 0.10)
                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        }
    }

    // MARK: - Front panel (solid, with discipline name ON it)

    private func frontPanel(width w: CGFloat, height h: CGFloat, mainColor: Color, darkColor: Color) -> some View {
        ZStack(alignment: .bottom) {
            // Main front body — solid opaque
            UnevenRoundedRectangle(
                topLeadingRadius: 3,
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 8,
                topTrailingRadius: 3
            )
            .fill(
                LinearGradient(
                    colors: [mainColor, darkColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: w - 2, height: h * 0.62)
            // Top edge highlight (subtle light line)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.25), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
                    .padding(.horizontal, 4)
                    .offset(y: 1)
            }
            // Rim dourado sutil (mesma família do glassBorder do DS)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 3,
                    bottomLeadingRadius: 8,
                    bottomTrailingRadius: 8,
                    topTrailingRadius: 3
                )
                .stroke(VitaColors.glassBorder, lineWidth: 0.5)
                .frame(width: w - 2, height: h * 0.62)
            )

            // Content on front panel: name + star + vitaScore
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Nome COSTURADO na pasta: texto branco gravado no material +
                // fio de pontos na cor da disciplina (detalhe artesanal). Sem box.
                Text(Self.folderLabel(subjectName))
                    .font(.system(size: 9.5, weight: .bold))  // ds-allow: nome gravado na pasta
                    .tracking(0.6)
                    .foregroundStyle(Color.white.opacity(0.92))  // ds-allow: texto branco gravado
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .shadow(color: .black.opacity(0.55), radius: 0.5, x: 0, y: 1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)

                Spacer(minLength: 0)

                // Bottom row: star left, vitaScore right
                HStack {
                    Button {
                        Self.toggleFavorite(subjectName)
                        withAnimation(.easeInOut(duration: 0.2)) { starred.toggle() }
                    } label: {
                        Image(systemName: starred ? "star.fill" : "star")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(starred ? VitaColors.accentHover : Color.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if itemCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 6.5, weight: .semibold))  // ds-allow: contador de materiais da pasta
                            Text("\(itemCount)")
                                .font(.system(size: 8, weight: .bold, design: .rounded))  // ds-allow: contador de materiais
                        }
                        .foregroundStyle(VitaColors.goldText.opacity(0.75))
                    }

                    if onMenu != nil {
                        Button { onMenu?() } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 7)
                .padding(.bottom, 5)
            }
            .frame(width: w - 2, height: h * 0.62)
        }
        .offset(y: h * 0.19)
    }

    // MARK: - Favorites persistence

    private static let favKey = "vita_favorite_disciplines"

    static func isFavorite(_ subject: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: favKey) ?? []).contains(subject)
    }

    static func toggleFavorite(_ subject: String) {
        var set = UserDefaults.standard.stringArray(forKey: favKey) ?? []
        if set.contains(subject) {
            set.removeAll { $0 == subject }
        } else {
            set.append(subject)
        }
        UserDefaults.standard.set(set, forKey: favKey)
    }

    static func favorites() -> [String] {
        UserDefaults.standard.stringArray(forKey: favKey) ?? []
    }
}

// MARK: - StitchLine (fio de costura sob o nome)

private struct StitchLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - BackTab shape (the tab nub on the back panel)

private struct BackTab: Shape {
    let color: Color

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 3
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
        p.addLine(to: CGPoint(x: rect.maxX - r * 3, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX - r, y: rect.maxY * 0.3)
        )
        p.closeSubpath()
        return p
    }
}

extension BackTab: View {
    var body: some View {
        self.fill(
            LinearGradient(
                colors: [color, color.opacity(0.80)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
