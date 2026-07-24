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

// MARK: - Ícone CANÔNICO por SLUG (drawer da Jornada)
// Cada disciplina da árvore Vita tem UM ícone + UMA cor próprios — ZERO
// repetição DENTRO de uma área (garantido por script de validação). Keyed por
// SLUG exato pra não colidir como o matcher por keyword — que fazia toda "X
// Pediátrica" virar o mesmo bonequinho. Subspecialidade pediátrica herda o
// ícone do órgão/tema (coração=cardiologia…). Símbolos conferidos contra o
// CoreGlyphs do iOS 26.4 — nome inválido renderiza vazio.
extension DisciplineImages {
    private static let bySlug: [String: (symbol: String, color: Color)] = [
        // Ciclo Básico
        "anatomia": ("figure.stand", VitaColors.dataAmber),
        "biofisica": ("waveform.path", VitaColors.dataIndigo),
        "biologia-celular": ("circle.hexagongrid.fill", VitaColors.dataTeal),
        "bioquimica": ("flask.fill", VitaColors.dataGreen),
        "embriologia": ("sparkles", VitaColors.dataBlue),
        "farmacologia": ("pills.fill", VitaColors.dataTeal),
        "fisiologia-1": ("waveform.path.ecg", VitaColors.dataRed),
        "genetica": ("atom", VitaColors.dataIndigo),
        "histologia": ("testtube.2", VitaColors.dataAmber),
        "imunologia": ("shield.lefthalf.filled", VitaColors.dataBlue),
        "micologia-medica": ("allergens.fill", VitaColors.dataGreen),
        "microbiologia": ("microbe.fill", VitaColors.dataTeal),
        "neuroanatomia": ("brain.fill", VitaColors.dataIndigo),
        "parasitologia": ("ant.fill", VitaColors.dataAmber),
        "patologia-especial": ("text.magnifyingglass", VitaColors.dataRed),
        "patologia-geral": ("magnifyingglass", VitaColors.accent),
        // Clínica Médica
        "cardiologia": ("heart.fill", VitaColors.dataRed),
        "clinica-medica-1": ("stethoscope", VitaColors.dataTeal),
        "cuidados-paliativos": ("bed.double.fill", VitaColors.dataIndigo),
        "dermatologia": ("bandage.fill", VitaColors.dataAmber),
        "endocrinologia": ("custom:tireoide", VitaColors.dataRed),
        "gastroenterologia": ("custom:estomago", VitaColors.dataAmber),
        "geriatria": ("figure.walk.motion", VitaColors.dataBlue),
        "hematologia": ("drop.fill", VitaColors.dataRed),
        "infectologia": ("cross.vial.fill", VitaColors.dataGreen),
        "nefrologia": ("custom:rim", VitaColors.dataBlue),
        "neurologia": ("brain.head.profile", VitaColors.dataIndigo),
        "oncologia": ("rays", VitaColors.accent),
        "pneumologia": ("lungs.fill", VitaColors.dataBlue),
        "psiquiatria-1": ("brain.filled.head.profile", VitaColors.dataIndigo),
        "radiologia": ("camera.aperture", VitaColors.dataTeal),
        "reumatologia": ("figure.walk", VitaColors.dataAmber),
        "semiologia": ("list.clipboard.fill", VitaColors.accent),
        "terapia-intensiva": ("waveform.path.ecg.rectangle.fill", VitaColors.dataRed),
        "toxicologia": ("exclamationmark.triangle.fill", VitaColors.dataAmber),
        "urgencia-emergencia": ("cross.case.fill", VitaColors.dataRed),
        // Cirurgia
        "anestesiologia": ("moon.zzz.fill", VitaColors.dataIndigo),
        "cirurgia-1": ("scissors", VitaColors.dataTeal),
        "oftalmologia": ("eye.fill", VitaColors.dataBlue),
        "ortopedia": ("custom:osso", VitaColors.dataAmber),
        "otorrino": ("ear.fill", VitaColors.dataTeal),
        "urologia": ("custom:bexiga", VitaColors.dataBlue),
        // Gineco e Obstetrícia
        "hemorragias-obstetricas": ("drop.circle.fill", VitaColors.dataRed),
        "assistencia-pre-natal": ("heart.text.clipboard.fill", VitaColors.accent),
        "atencao-integral-saude-mulher": ("hand.raised.fill", VitaColors.dataRed),
        "fisiologia-fetal-embriologia-go": ("heart.circle.fill", VitaColors.dataBlue),
        "intercorrencias-clinicas-gestacao": ("medical.thermometer.fill", VitaColors.dataAmber),
        "ginecologia-benigna-dor-pelvica": ("heart.text.square.fill", VitaColors.dataIndigo),
        "go-1": ("staroflife.fill", VitaColors.dataTeal),
        "ginecologia-endocrina": ("custom:tireoide", VitaColors.dataAmber),
        "infeccoes-ginecologicas": ("facemask.fill", VitaColors.dataGreen),
        "mastologia": ("circle.circle.fill", VitaColors.dataRed),
        "medicina-fetal": ("dot.radiowaves.left.and.right", VitaColors.dataBlue),
        "oncologia-ginecologica-trato-genital-inferior": ("cross.case.circle.fill", VitaColors.dataIndigo),
        "reproducao-humana-planejamento-reprodutivo": ("figure.2.and.child.holdinghands", VitaColors.dataTeal),
        "puerperio": ("stroller.fill", VitaColors.dataAmber),
        "trabalho-parto-parto": ("figure.child.circle.fill", VitaColors.dataBlue),
        "uroginecologia-assoalho-pelvico": ("figure.stand.dress", VitaColors.accent),
        // Pediatria
        "adolescencia": ("sunglasses.fill", VitaColors.dataBlue),
        "cardiologia-pediatrica": ("heart.fill", VitaColors.dataRed),
        "cirurgia-pediatrica": ("scissors", VitaColors.dataTeal),
        "dermatologia-pediatrica": ("bandage.fill", VitaColors.dataAmber),
        "doencas-infecciosas-pediatricas": ("microbe.fill", VitaColors.dataGreen),
        "endocrinologia-pediatrica": ("custom:tireoide", VitaColors.dataAmber),
        "gastroenterologia-pediatrica": ("custom:estomago", VitaColors.dataAmber),
        "genetica-clinica-pediatrica": ("atom", VitaColors.dataIndigo),
        "hematologia-pediatrica": ("drop.fill", VitaColors.dataRed),
        "imunizacoes-pediatricas": ("syringe.fill", VitaColors.dataTeal),
        "imunologia-alergia-pediatrica": ("allergens.fill", VitaColors.dataGreen),
        "medicina-intensiva-pediatrica": ("waveform.path.ecg.rectangle.fill", VitaColors.dataRed),
        "nefrologia-pediatrica": ("custom:rim", VitaColors.dataBlue),
        "neonatologia": ("stroller.fill", VitaColors.dataGreen),
        "neurologia-pediatrica": ("brain.head.profile", VitaColors.dataIndigo),
        "nutrologia-pediatrica": ("carrot.fill", VitaColors.dataAmber),
        "oftalmologia-pediatrica": ("eye.fill", VitaColors.dataBlue),
        "oncologia-pediatrica": ("rays", VitaColors.accent),
        "pediatria-1": ("teddybear.fill", VitaColors.dataAmber),
        "pneumologia-pediatrica": ("lungs.fill", VitaColors.dataBlue),
        "protecao-violencias-infancia-adolescencia": ("hand.raised.fill", VitaColors.dataRed),
        "puericultura-crescimento": ("figure.child", VitaColors.dataGreen),
        "reumatologia-pediatrica": ("figure.walk", VitaColors.dataAmber),
        "urgencias-pediatricas": ("cross.case.fill", VitaColors.dataRed),
        // Preventiva e Social
        "atencao-primaria": ("house.fill", VitaColors.dataGreen),
        "comunicacao": ("bubble.left.and.bubble.right.fill", VitaColors.dataTeal),
        "epidemiologia": ("chart.bar.fill", VitaColors.dataBlue),
        "etica-medica": ("building.columns.fill", VitaColors.accent),
        "humanidades": ("book.closed.fill", VitaColors.dataAmber),
        "mfc-1": ("person.3.fill", VitaColors.dataGreen),
        "medicina-legal": ("scalemass.fill", VitaColors.dataIndigo),
        "psicologia-medica": ("brain.filled.head.profile", VitaColors.accent),
        "saude-coletiva-1": ("person.2.fill", VitaColors.dataBlue),
        "saude-do-trabalhador": ("hammer.fill", VitaColors.dataAmber),
        "saude-publica": ("globe.americas.fill", VitaColors.dataTeal),
    ]

    /// Ícone da disciplina pelo SLUG (preferido, sem colisão). Sem slug no mapa
    /// (baralho/tag livre) → cai no matcher por nome.
    static func iconSpec(slug: String?, name: String) -> (symbol: String, color: Color) {
        if let slug, let hit = bySlug[slug] { return hit }
        return iconSpec(for: name)
    }
}

// MARK: - Rótulo curto de exibição (drawer da Jornada)
// Nome LIMPO pra caber legível na pastilha: 1 linha quando a palavra cabe
// (encolhe de leve, NUNCA quebra no meio da palavra), 2 linhas com "\n" numa
// fronteira de palavra/morfema pros longos (Neuro / anatomia). A View aplica
// lineLimit 1 ou 2 conforme houver "\n".
extension DisciplineImages {
    private static let labelBySlug: [String: String] = [
        "anatomia": "Anatomia",
        "biofisica": "Biofísica",
        "biologia-celular": "Biologia\nCelular",
        "bioquimica": "Bioquímica",
        "embriologia": "Embriologia",
        "farmacologia": "Farmacologia",
        "fisiologia-1": "Fisiologia I",
        "genetica": "Genética",
        "histologia": "Histologia",
        "imunologia": "Imunologia",
        "micologia-medica": "Micologia",
        "microbiologia": "Microbiologia",
        "neuroanatomia": "Neuro-\nanatomia",
        "parasitologia": "Parasitologia",
        "patologia-especial": "Patologia\nEspecial",
        "patologia-geral": "Patologia\nGeral",
        "cardiologia": "Cardiologia",
        "clinica-medica-1": "Clínica\nMédica I",
        "cuidados-paliativos": "Cuidados\nPaliativos",
        "dermatologia": "Dermatologia",
        "endocrinologia": "Endócrino",
        "gastroenterologia": "Gastro-\nenterologia",
        "geriatria": "Geriatria",
        "hematologia": "Hematologia",
        "infectologia": "Infectologia",
        "nefrologia": "Nefrologia",
        "neurologia": "Neurologia",
        "oncologia": "Oncologia",
        "pneumologia": "Pneumologia",
        "psiquiatria-1": "Psiquiatria",
        "radiologia": "Radiologia",
        "reumatologia": "Reumatologia",
        "semiologia": "Semiologia",
        "terapia-intensiva": "Terapia\nIntensiva",
        "toxicologia": "Toxicologia",
        "urgencia-emergencia": "Urgência e\nEmergência",
        "anestesiologia": "Anestesia",
        "cirurgia-1": "Cirurgia I",
        "oftalmologia": "Oftalmologia",
        "ortopedia": "Ortopedia",
        "otorrino": "Otorrino",
        "urologia": "Urologia",
        "hemorragias-obstetricas": "Hemorragias\nObstétricas",
        "assistencia-pre-natal": "Pré-natal",
        "atencao-integral-saude-mulher": "Saúde da\nMulher",
        "fisiologia-fetal-embriologia-go": "Fisiologia\nFetal",
        "intercorrencias-clinicas-gestacao": "Gestação de\nAlto Risco",
        "ginecologia-benigna-dor-pelvica": "Gineco\nBenigna",
        "go-1": "Gineco e\nObst. I",
        "ginecologia-endocrina": "Gineco\nEndócrina",
        "infeccoes-ginecologicas": "Infecções\nGineco",
        "mastologia": "Mastologia",
        "medicina-fetal": "Medicina\nFetal",
        "oncologia-ginecologica-trato-genital-inferior": "Oncologia\nGineco",
        "reproducao-humana-planejamento-reprodutivo": "Planejam.\nReprodutivo",
        "puerperio": "Puerpério",
        "trabalho-parto-parto": "Trabalho\nde Parto",
        "uroginecologia-assoalho-pelvico": "Assoalho\nPélvico",
        "adolescencia": "Adolescência",
        "cardiologia-pediatrica": "Cardio\nPediátrica",
        "cirurgia-pediatrica": "Cirurgia\nPediátrica",
        "dermatologia-pediatrica": "Derma\nPediátrica",
        "doencas-infecciosas-pediatricas": "Doenças\nInfecciosas",
        "endocrinologia-pediatrica": "Endócrino\nPediátrica",
        "gastroenterologia-pediatrica": "Gastro\nPediátrica",
        "genetica-clinica-pediatrica": "Genética\nPediátrica",
        "hematologia-pediatrica": "Hemato\nPediátrica",
        "imunizacoes-pediatricas": "Imunizações",
        "imunologia-alergia-pediatrica": "Alergia\nPediátrica",
        "medicina-intensiva-pediatrica": "UTI\nPediátrica",
        "nefrologia-pediatrica": "Nefro\nPediátrica",
        "neonatologia": "Neonatologia",
        "neurologia-pediatrica": "Neuro\nPediátrica",
        "nutrologia-pediatrica": "Nutro\nPediátrica",
        "oftalmologia-pediatrica": "Oftalmo\nPediátrica",
        "oncologia-pediatrica": "Onco\nPediátrica",
        "pediatria-1": "Pediatria I",
        "pneumologia-pediatrica": "Pneumo\nPediátrica",
        "protecao-violencias-infancia-adolescencia": "Proteção\nà Infância",
        "puericultura-crescimento": "Puericultura",
        "reumatologia-pediatrica": "Reumato\nPediátrica",
        "urgencias-pediatricas": "Urgências\nPediátricas",
        "atencao-primaria": "Atenção\nPrimária",
        "comunicacao": "Comunicação",
        "epidemiologia": "Epidemiologia",
        "etica-medica": "Ética Médica",
        "humanidades": "Humanidades",
        "mfc-1": "Med. de\nFamília",
        "medicina-legal": "Medicina\nLegal",
        "psicologia-medica": "Psicologia\nMédica",
        "saude-coletiva-1": "Saúde\nColetiva",
        "saude-do-trabalhador": "Saúde do\nTrabalhador",
        "saude-publica": "Saúde\nPública",
    ]

    /// Rótulo de exibição da disciplina (por slug). Fallback = nome cru.
    static func shortLabel(slug: String?, name: String) -> String {
        if let slug, let l = labelBySlug[slug] { return l }
        return name
    }
}
