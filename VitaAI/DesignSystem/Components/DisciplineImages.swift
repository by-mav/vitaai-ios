import SwiftUI

// MARK: - DisciplineImages
// Maps discipline names (from API) to asset catalog image names (disc-{slug}).
// Images are the red/fire circular badges generated via ComfyUI.
// Every discipline has its own unique image — no fallback reuse.

enum DisciplineImages {

    /// Keyword → asset mapping. Each discipline maps to its OWN unique image.
    private static let slugs: [(keywords: [String], asset: String)] = [
        (["anatomia"], "disc-anatomia"),
        (["anestesiologia"], "disc-anestesiologia"),
        (["atencao primaria", "atenção primária", "atencao a saude"], "disc-atencao-primaria"),
        (["bioetica", "bioética"], "disc-bioetica"),
        (["biofisica", "biofísica"], "disc-biofisica"),
        (["biologia celular", "biologia molecular"], "disc-biologia-celular"),
        (["bioquimica", "bioquímica"], "disc-bioquimica"),
        (["biosseguranca", "biossegurança"], "disc-biosseguranca"),
        (["cardiologia"], "disc-cardiologia"),
        (["cirurgia 1", "cirurgia i", "tecnica cirurgica", "técnica cirúrgica"], "disc-cirurgia-1"),
        (["cirurgia 2", "cirurgia ii"], "disc-cirurgia-2"),
        (["cirurgia plastica", "cirurgia plástica"], "disc-cirurgia-plastica"),
        (["clinica medica 1", "clínica médica 1", "clinica medica i", "clínica médica i"], "disc-clinica-medica-1"),
        (["clinica medica 2", "clínica médica 2", "clinica medica ii", "clínica médica ii"], "disc-clinica-medica-2"),
        (["comunicacao", "comunicação"], "disc-comunicacao"),
        (["cuidados paliativos"], "disc-cuidados-paliativos"),
        (["dermatologia"], "disc-dermatologia"),
        (["direitos humanos"], "disc-direitos-humanos"),
        (["doencas tropicais", "doenças tropicais", "tropical"], "disc-doencas-tropicais"),
        (["embriologia"], "disc-embriologia"),
        (["empreendedorismo"], "disc-empreendedorismo"),
        (["endocrinologia"], "disc-endocrinologia"),
        (["epidemiologia"], "disc-epidemiologia"),
        (["espiritualidade", "saúde espiritual"], "disc-espiritualidade-saude"),
        (["estatistica", "estatística"], "disc-estatistica"),
        (["etica medica", "ética médica"], "disc-etica-medica"),
        (["farmacologia clinica", "farmacologia clínica"], "disc-farmacologia-clinica"),
        (["farmacologia"], "disc-farmacologia"),
        (["fisiologia 2", "fisiologia ii"], "disc-fisiologia-2"),
        (["fisiologia"], "disc-fisiologia-1"),
        (["gastroenterologia"], "disc-gastroenterologia"),
        (["genetica", "genética"], "disc-genetica"),
        (["geriatria"], "disc-geriatria"),
        (["gestao", "gestão em saúde"], "disc-gestao-saude"),
        (["ginecologia", "obstetricia", "obstetrícia", "go 1", "go i"], "disc-go-1"),
        (["go 2", "go ii"], "disc-go-2"),
        (["hematologia"], "disc-hematologia"),
        (["histologia"], "disc-histologia"),
        (["humanidades", "sociedade", "contemporaneidade"], "disc-humanidades"),
        (["imunologia"], "disc-imunologia"),
        (["infectologia"], "disc-infectologia"),
        (["ingles", "inglês"], "disc-ingles-medico"),
        (["internato cir"], "disc-internato-cir"),
        (["internato cm", "internato clinica"], "disc-internato-cm"),
        (["internato go", "internato ginec"], "disc-internato-go"),
        (["internato ped"], "disc-internato-ped"),
        (["internato sc", "internato saude coletiva"], "disc-internato-sc"),
        (["internato sm", "internato saude mental"], "disc-internato-sm"),
        (["internato ue", "internato urgencia"], "disc-internato-ue"),
        (["internato"], "disc-internato"),
        (["interprofissional"], "disc-interprofissional"),
        (["introducao", "introdução"], "disc-introducao-medicina"),
        (["libras"], "disc-libras"),
        (["medicina baseada", "mbe", "evidencia", "evidência"], "disc-medicina-baseada-evidencia"),
        (["medicina esportiva", "esporte"], "disc-medicina-esporte"),
        (["medicina legal", "deontologia"], "disc-medicina-legal"),
        (["medicina reprodutiva", "reprodutiva"], "disc-medicina-reprodutiva"),
        (["metodologia", "científica"], "disc-metodologia-cientifica"),
        (["mfc", "medicina de familia", "medicina de família", "comunidade"], "disc-mfc-1"),
        (["micologia"], "disc-micologia-medica"),
        (["microbiologia"], "disc-microbiologia"),
        (["nefrologia"], "disc-nefrologia"),
        (["neonatologia"], "disc-neonatologia"),
        (["neuroanatomia"], "disc-neuroanatomia"),
        (["neurociencias", "neurociências"], "disc-neurociencias"),
        (["neurocirurgia"], "disc-neurocirurgia"),
        (["neurologia"], "disc-neurologia"),
        (["nutrologia", "nutricao", "nutrição"], "disc-nutrologia"),
        (["oftalmologia"], "disc-oftalmologia"),
        (["oncologia"], "disc-oncologia"),
        (["ortopedia", "traumatologia"], "disc-ortopedia"),
        (["otorrino", "otorrinolaringologia"], "disc-otorrino"),
        (["parasitologia"], "disc-parasitologia"),
        (["patologia especial"], "disc-patologia-especial"),
        (["patologia"], "disc-patologia-geral"),
        (["pediatria 2", "pediatria ii"], "disc-pediatria-2"),
        (["pediatria"], "disc-pediatria-1"),
        (["pneumologia"], "disc-pneumologia"),
        (["psicologia"], "disc-psicologia-medica"),
        (["psiquiatria"], "disc-psiquiatria-1"),
        (["radiologia", "diagnóstico por imagem"], "disc-radiologia"),
        (["reumatologia"], "disc-reumatologia"),
        (["saude coletiva", "saúde coletiva"], "disc-saude-coletiva-1"),
        (["saude digital", "saúde digital"], "disc-saude-digital"),
        (["saude do trabalhador", "saúde do trabalhador"], "disc-saude-do-trabalhador"),
        (["saude indigena", "saúde indígena"], "disc-saude-indigena"),
        (["saude meio ambiente", "saúde e meio ambiente"], "disc-saude-meio-ambiente"),
        (["saude planetaria", "saúde planetária"], "disc-saude-planetaria"),
        (["populacao negra", "população negra"], "disc-saude-populacao-negra"),
        (["saude publica", "saúde pública"], "disc-saude-publica"),
        (["semiologia"], "disc-semiologia"),
        (["tecnica operatoria", "técnica operatória"], "disc-tecnica-operatoria"),
        (["terapia intensiva", "uti"], "disc-terapia-intensiva"),
        (["toxicologia"], "disc-toxicologia"),
        (["transplantologia", "transplante"], "disc-transplantologia"),
        (["urgencia", "urgência", "emergencia", "emergência"], "disc-urgencia-emergencia"),
        (["urologia"], "disc-urologia"),
    ]

    /// Returns the asset catalog image name for a discipline.
    static func imageAsset(for disciplineName: String) -> String {
        let normalized = disciplineName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()

        for entry in slugs {
            for keyword in entry.keywords {
                let kw = keyword
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
                    .lowercased()
                if normalized.contains(kw) || kw.contains(normalized) {
                    return entry.asset
                }
            }
        }

        return "disc-interprofissional"
    }
}
