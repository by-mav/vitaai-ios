import Foundation

// MARK: - Ofensiva

/// O que alimenta a tela "Sua ofensiva".
///
/// Espelha GET /api/gamification/streak (openapi.yaml, operationId
/// getStreakCalendar). Conta APENAS estudo real — abrir o app nao entra.
struct Ofensiva: Codable, Equatable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var freezesAvailable: Int = 0
    var studiedToday: Bool = false
    var month: String = ""
    /// Dia de hoje no fuso do servidor (ISO). Chave da comemoracao 1x/dia.
    var today: String = ""
    var days: [DiaOfensiva] = []
    var milestones: [MarcoOfensiva] = []

    /// Resposta parcial nao pode zerar a tela inteira: cada campo cai no seu
    /// proprio default em vez de derrubar o decode (mesmo padrao do
    /// ProgressResponse, Rafael 2026-07-09).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentStreak = (try? c.decode(Int.self, forKey: .currentStreak)) ?? 0
        longestStreak = (try? c.decode(Int.self, forKey: .longestStreak)) ?? 0
        freezesAvailable = (try? c.decode(Int.self, forKey: .freezesAvailable)) ?? 0
        studiedToday = (try? c.decode(Bool.self, forKey: .studiedToday)) ?? false
        month = (try? c.decode(String.self, forKey: .month)) ?? ""
        today = (try? c.decode(String.self, forKey: .today)) ?? ""
        days = (try? c.decode([DiaOfensiva].self, forKey: .days)) ?? []
        milestones = (try? c.decode([MarcoOfensiva].self, forKey: .milestones)) ?? []
    }

    init(currentStreak: Int = 0, longestStreak: Int = 0, freezesAvailable: Int = 0,
         studiedToday: Bool = false, month: String = "", today: String = "",
         days: [DiaOfensiva] = [], milestones: [MarcoOfensiva] = []) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.freezesAvailable = freezesAvailable
        self.studiedToday = studiedToday
        self.month = month
        self.today = today
        self.days = days
        self.milestones = milestones
    }

    /// Bateu o proprio recorde agora (usado na frase do card herói).
    var eRecordePessoal: Bool { currentStreak > 0 && currentStreak >= longestStreak }

    /// Quantos dias faltam pro recorde. Nil quando ja e recorde.
    var diasParaRecorde: Int? {
        guard !eRecordePessoal else { return nil }
        return max(1, longestStreak - currentStreak)
    }

    /// Proximo marco ainda nao alcancado.
    var proximoMarco: MarcoOfensiva? { milestones.first { !$0.reached } }
}

struct DiaOfensiva: Codable, Equatable, Identifiable {
    /// ISO YYYY-MM-DD, ja no fuso de Sao Paulo (o servidor corta o dia).
    let date: String
    let kind: Kind

    var id: String { date }

    enum Kind: String, Codable {
        /// Estudo registrado — chama cheia.
        case study
        /// Plantao coberto. INFERIDO pelo servidor (o gasto de plantao nao e
        /// registrado), entao e escudo, nao chama.
        case covered
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = (try? c.decode(String.self, forKey: .date)) ?? ""
        kind = (try? c.decode(Kind.self, forKey: .kind)) ?? .study
    }

    init(date: String, kind: Kind) {
        self.date = date
        self.kind = kind
    }
}

struct MarcoOfensiva: Codable, Equatable, Identifiable {
    let days: Int
    let reached: Bool

    var id: Int { days }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = (try? c.decode(Int.self, forKey: .days)) ?? 0
        reached = (try? c.decode(Bool.self, forKey: .reached)) ?? false
    }

    init(days: Int, reached: Bool) {
        self.days = days
        self.reached = reached
    }
}
