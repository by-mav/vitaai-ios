import SwiftUI

// MARK: - DisciplineImages
// Maps discipline names (from API) to asset catalog image names (disc-{slug}).
// Images are the red/fire circular badges generated via ComfyUI.
// Every discipline has its own unique image — no fallback reuse.

enum DisciplineImages {

    /// Keyword → asset mapping. Each discipline maps to its OWN unique image.
    // A tabela de IMAGENS por disciplina (~97 fotos) foi REMOVIDA em 2026-07-20.
    // Ela existia só pra alimentar um ícone de 28px numa única tela (Faculdade >
    // Documentos) enquanto o resto do app já usava `iconSpec` (símbolo + cor).
    // Eram dois sistemas de ícone concorrentes pra mesma coisa; ficou um.
    // Precisa de ícone de disciplina? Use `DisciplineIconBadge(name:size:)`.
}

// MARK: - Ícone redondo por disciplina (símbolo + cor)
// Badge limpo pra listas (baralhos, disciplinas): um glifo SF Symbol semântico
// sobre um círculo com gradiente da cor da disciplina. Cor semântica quando a
// disciplina é conhecida (coração=cardio, pulmão=pneumo…); fallback determinístico
// pra qualquer nome, sempre estável (mesma disciplina → mesma cor).
extension DisciplineImages {
    /// (símbolo SF, cor) por palavra-chave da disciplina.
    private static let iconSpecs: [(keywords: [String], symbol: String, color: Color)] = [
        (["cardiolog"], "heart.fill", VitaColors.dataRed),
        (["pneumo", "respirat"], "lungs.fill", VitaColors.dataBlue),
        (["neuroanatom", "neurolog", "neuro"], "brain.head.profile", VitaColors.dataIndigo),
        (["psiquiat", "saude mental", "psicolog"], "brain.head.profile", VitaColors.dataIndigo),
        (["farmacolog"], "pills.fill", VitaColors.dataTeal),
        (["anatom"], "figure.stand", VitaColors.dataAmber),
        (["bioquim", "biofisica", "biologia molecular", "biologia celular"], "atom", VitaColors.dataTeal),
        (["microbiolog", "parasitolog", "imunolog"], "cross.vial.fill", VitaColors.dataGreen),
        (["genetic"], "atom", VitaColors.dataIndigo),
        (["fisiolog"], "waveform.path.ecg", VitaColors.dataRed),
        (["patolog"], "cross.vial.fill", VitaColors.dataRed),
        (["histolog", "citolog", "embriolog"], "circle.hexagongrid.fill", VitaColors.dataTeal),
        (["semiolog"], "stethoscope", VitaColors.accent),
        (["clinica medica", "clinica cirurgica"], "stethoscope", VitaColors.dataTeal),
        (["dermatolog"], "bandage.fill", VitaColors.dataAmber),
        (["oftalmolog"], "eye.fill", VitaColors.dataBlue),
        (["otorrino"], "ear.fill", VitaColors.dataAmber),
        (["ortoped", "reumatolog"], "figure.walk", VitaColors.dataBlue),
        (["urolog", "nefrolog"], "drop.fill", VitaColors.dataBlue),
        (["gastro"], "fork.knife", VitaColors.dataAmber),
        (["endocrinolog"], "bolt.heart.fill", VitaColors.dataRed),
        (["ginecolog", "obstetr"], "heart.text.square.fill", VitaColors.dataRed),
        (["pediatr"], "figure.child", VitaColors.dataGreen),
        (["geriatr"], "figure.walk", VitaColors.dataBlue),
        (["cirurg", "tecnica cirurgica", "tecnica operatoria"], "scissors", VitaColors.dataTeal),
        (["anestesiolog"], "moon.zzz.fill", VitaColors.dataIndigo),
        (["oncolog"], "cross.case.fill", VitaColors.dataRed),
        (["infectolog", "doencas tropicais", "tropical"], "cross.vial.fill", VitaColors.dataGreen),
        (["hematolog"], "drop.fill", VitaColors.dataRed),
        (["radiolog", "imagem"], "dot.radiowaves.left.and.right", VitaColors.dataBlue),
        (["emergencia", "urgencia", "terapia intensiva", "uti"], "cross.case.fill", VitaColors.dataRed),
        (["epidemiolog", "saude publica", "saude coletiva", "bioestatistica", "estatistica", "medicina preventiva", "preventiva"], "chart.bar.fill", VitaColors.dataBlue),
        (["ciclo basico", "ciencias basicas"], "atom", VitaColors.dataTeal),
        (["etica", "direitos humanos", "medicina legal", "deontolog"], "building.columns.fill", VitaColors.accent),
        (["nutri"], "leaf.fill", VitaColors.dataGreen),
        (["atencao primaria", "saude da familia", "medicina de familia", "familia", "comunidade"], "house.fill", VitaColors.dataGreen),
        (["comunicacao"], "bubble.left.and.bubble.right.fill", VitaColors.dataTeal),
        (["cuidados paliativos", "espiritual"], "heart.circle.fill", VitaColors.dataIndigo),
        (["interprofissional", "integracao"], "person.2.fill", VitaColors.accent),
        (["empreendedorismo", "gestao"], "briefcase.fill", VitaColors.dataAmber),
        // As 10 disciplinas canônicas que caíam no fallback (a maletinha) — medido
        // 2026-07-17 cruzando `vita.disciplines` com este mapa. Toda disciplina da
        // árvore tem símbolo próprio; a maletinha fica só pra baralho sem disciplina.
        (["neonatolog"], "figure.child.circle.fill", VitaColors.dataGreen),
        (["nutrolog"], "carrot.fill", VitaColors.dataAmber),
        (["toxicolog"], "exclamationmark.triangle.fill", VitaColors.dataAmber),
        (["micolog"], "allergens.fill", VitaColors.dataGreen),
        (["transplantolog", "transplante"], "arrow.triangle.2.circlepath", VitaColors.dataTeal),
        (["medicina do esporte", "medicina esportiva", "esporte"], "figure.run", VitaColors.dataBlue),
        (["saude do trabalhador", "trabalhador"], "hammer.fill", VitaColors.dataBlue),
        (["metodologia", "cientific", "pesquisa"], "magnifyingglass", VitaColors.dataIndigo),
        (["humanidades", "sociedade e saude", "sociedade"], "book.closed.fill", VitaColors.accent),
    ]

    private static let iconPalette: [Color] = [
        VitaColors.accent, VitaColors.dataBlue, VitaColors.dataGreen,
        VitaColors.dataAmber, VitaColors.dataRed, VitaColors.dataIndigo, VitaColors.dataTeal,
    ]

    /// Hash estável (djb2) — NÃO usar String.hashValue (randomiza por processo → cor
    /// mudaria a cada abertura do app).
    private static func stableHash(_ s: String) -> Int {
        var h = 5381
        for scalar in s.unicodeScalars { h = (h &* 33) &+ Int(scalar.value) }
        return abs(h)
    }

    /// Símbolo + cor pro badge redondo da disciplina.
    static func iconSpec(for disciplineName: String) -> (symbol: String, color: Color) {
        // Slugs vêm com hífen ("atencao-primaria"); as keywords usam espaço →
        // normalizar hífen/underscore pra espaço pra casar os dois.
        let normalized = disciplineName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        for spec in iconSpecs {
            for keyword in spec.keywords {
                let kw = keyword
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
                    .lowercased()
                if !kw.isEmpty, normalized.contains(kw) {
                    return (spec.symbol, spec.color)
                }
            }
        }
        return ("cross.case.fill", iconPalette[stableHash(normalized) % iconPalette.count])
    }
}
