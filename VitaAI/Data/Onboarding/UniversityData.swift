import Foundation

let brazilianMedicalSchools: [University] = [
    // AC
    University(name: "Universidade Federal do Acre", shortName: "UFAC", city: "Rio Branco", state: "AC"),
    // AL
    University(name: "Universidade Federal de Alagoas", shortName: "UFAL", city: "Maceió", state: "AL"),
    University(name: "Universidade Estadual de Ciências da Saúde de Alagoas", shortName: "UNCISAL", city: "Maceió", state: "AL"),
    University(name: "Centro Universitário CESMAC", shortName: "CESMAC", city: "Maceió", state: "AL"),
    // AM
    University(name: "Universidade Federal do Amazonas", shortName: "UFAM", city: "Manaus", state: "AM"),
    University(name: "Universidade do Estado do Amazonas", shortName: "UEA", city: "Manaus", state: "AM"),
    University(name: "Universidade Nilton Lins", shortName: "NILTON LINS", city: "Manaus", state: "AM"),
    // AP
    University(name: "Universidade Federal do Amapá", shortName: "UNIFAP", city: "Macapá", state: "AP"),
    // BA
    University(name: "Universidade Federal da Bahia", shortName: "UFBA", city: "Salvador", state: "BA"),
    University(name: "Universidade Estadual de Feira de Santana", shortName: "UEFS", city: "Feira de Santana", state: "BA"),
    University(name: "Universidade Estadual de Santa Cruz", shortName: "UESC", city: "Ilhéus", state: "BA"),
    University(name: "Universidade Estadual do Sudoeste da Bahia", shortName: "UESB", city: "Vitória da Conquista", state: "BA"),
    University(name: "Escola Bahiana de Medicina e Saúde Pública", shortName: "EBMSP", city: "Salvador", state: "BA"),
    University(name: "Universidade Federal do Recôncavo da Bahia", shortName: "UFRB", city: "Santo Antônio de Jesus", state: "BA"),
    University(name: "Universidade Federal do Sul da Bahia", shortName: "UFSB", city: "Teixeira de Freitas", state: "BA"),
    University(name: "Universidade Salvador", shortName: "UNIFACS", city: "Salvador", state: "BA"),
    // CE
    University(name: "Universidade Federal do Ceará", shortName: "UFC", city: "Fortaleza", state: "CE"),
    University(name: "Universidade Estadual do Ceará", shortName: "UECE", city: "Fortaleza", state: "CE"),
    University(name: "Universidade de Fortaleza", shortName: "UNIFOR", city: "Fortaleza", state: "CE"),
    University(name: "Centro Universitário Christus", shortName: "UNICHRISTUS", city: "Fortaleza", state: "CE"),
    University(name: "Universidade Federal do Cariri", shortName: "UFCA", city: "Barbalha", state: "CE"),
    // DF
    University(name: "Universidade de Brasília", shortName: "UnB", city: "Brasília", state: "DF"),
    University(name: "Centro Universitário de Brasília", shortName: "CEUB", city: "Brasília", state: "DF"),
    University(name: "Escola Superior de Ciências da Saúde", shortName: "ESCS", city: "Brasília", state: "DF"),
    // ES
    University(name: "Universidade Federal do Espírito Santo", shortName: "UFES", city: "Vitória", state: "ES"),
    University(name: "EMESCAM", shortName: "EMESCAM", city: "Vitória", state: "ES"),
    University(name: "Universidade Vila Velha", shortName: "UVV", city: "Vila Velha", state: "ES"),
    // GO
    University(name: "Universidade Federal de Goiás", shortName: "UFG", city: "Goiânia", state: "GO"),
    University(name: "Pontifícia Universidade Católica de Goiás", shortName: "PUC Goiás", city: "Goiânia", state: "GO"),
    // MG
    University(name: "Universidade Federal de Minas Gerais", shortName: "UFMG", city: "Belo Horizonte", state: "MG"),
    University(name: "Universidade Federal de Uberlândia", shortName: "UFU", city: "Uberlândia", state: "MG"),
    University(name: "Universidade Federal de Juiz de Fora", shortName: "UFJF", city: "Juiz de Fora", state: "MG"),
    University(name: "PUC Minas", shortName: "PUC Minas", city: "Belo Horizonte", state: "MG"),
    // PR
    University(name: "Universidade Federal do Paraná", shortName: "UFPR", city: "Curitiba", state: "PR"),
    University(name: "Universidade Estadual de Londrina", shortName: "UEL", city: "Londrina", state: "PR"),
    University(name: "Universidade Estadual de Maringá", shortName: "UEM", city: "Maringá", state: "PR"),
    University(name: "PUCPR", shortName: "PUCPR", city: "Curitiba", state: "PR"),
    // RJ
    University(name: "Universidade Federal do Rio de Janeiro", shortName: "UFRJ", city: "Rio de Janeiro", state: "RJ"),
    University(name: "Universidade Federal Fluminense", shortName: "UFF", city: "Niterói", state: "RJ"),
    University(name: "Universidade do Estado do Rio de Janeiro", shortName: "UERJ", city: "Rio de Janeiro", state: "RJ"),
    // RS
    University(name: "Universidade Federal do Rio Grande do Sul", shortName: "UFRGS", city: "Porto Alegre", state: "RS"),
    University(name: "PUCRS", shortName: "PUCRS", city: "Porto Alegre", state: "RS"),
    University(name: "Universidade Luterana do Brasil - Canoas", shortName: "ULBRA Canoas", city: "Canoas", state: "RS"),
    // SC
    University(name: "Universidade Federal de Santa Catarina", shortName: "UFSC", city: "Florianópolis", state: "SC"),
    // SP
    University(name: "Universidade de São Paulo", shortName: "USP", city: "São Paulo", state: "SP"),
    University(name: "Universidade Federal de São Paulo", shortName: "UNIFESP", city: "São Paulo", state: "SP"),
    University(name: "Universidade Estadual de Campinas", shortName: "UNICAMP", city: "Campinas", state: "SP"),
    University(name: "Faculdade de Ciências Médicas da Santa Casa de São Paulo", shortName: "FCMSCSP", city: "São Paulo", state: "SP"),
    University(name: "Faculdade de Medicina do ABC", shortName: "FMABC", city: "Santo André", state: "SP"),
]

let allStates: [String] = Array(Set(brazilianMedicalSchools.map(\.state))).sorted()

let medicineSubjectsBySemester: [Int: [String]] = [
    1: ["Anatomia I", "Bioquímica", "Histologia", "Embriologia", "Citologia", "Introdução à Medicina"],
    2: ["Anatomia II", "Fisiologia I", "Biofísica", "Genética Médica", "Imunologia", "Psicologia Médica"],
    3: ["Fisiologia II", "Microbiologia", "Parasitologia", "Patologia Geral", "Farmacologia I", "Saúde Coletiva I"],
    4: ["Patologia Especial", "Farmacologia II", "Semiologia I", "Propedêutica", "Saúde Coletiva II", "Epidemiologia"],
    5: ["Semiologia II", "Clínica Médica I", "Cirurgia I", "Obstetrícia I", "Pediatria I", "Medicina Legal"],
    6: ["Clínica Médica II", "Cirurgia II", "Obstetrícia II", "Pediatria II", "Psiquiatria", "Ortopedia"],
    7: ["Cardiologia", "Pneumologia", "Gastroenterologia", "Neurologia", "Dermatologia", "Oftalmologia"],
    8: ["Nefrologia", "Endocrinologia", "Hematologia", "Reumatologia", "Otorrinolaringologia", "Urologia"],
    9: ["Internato Clínica Médica", "Internato Cirurgia", "Internato Pediatria", "Plantão PS"],
    10: ["Internato Ginecologia e Obstetrícia", "Internato Saúde Mental", "Internato Saúde Coletiva", "Internato Medicina de Família"],
    11: ["Internato Urgência e Emergência", "Internato UTI", "Internato Ortopedia e Trauma", "Eletivo I"],
    12: ["Internato Eletivo II", "Internato Rural/UBS", "TCC", "Preparação para Residência"],
]
