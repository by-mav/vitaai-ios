import Foundation

/// Jornada universal do usuário VitaAI.
///
/// Substitui o conceito de "Faculdade" como tab única por uma tab "Jornada"
/// que renderiza template diferente conforme o tipo escolhido no onboarding.
///
/// SOT da decisão: agent-brain/decisions/2026-04-27_jornada-3lentes-FINAL.md
/// Schema backend: vita.user_profiles.journeyType (migration 0077, commit d2ab3a1).
enum JourneyType: String, Codable, CaseIterable {
    case faculdade = "FACULDADE"     // 1-8º semestre, em curso
    case internato = "INTERNATO"     // 9-12º semestre, rodízios
    case enamed = "ENAMED"           // exame federal de medicina
    case residencia = "RESIDENCIA"   // pós-grad, banca + especialidade
    case revalida = "REVALIDA"       // formado no exterior

    var displayName: String {
        switch self {
        case .faculdade: return "Faculdade"
        case .internato: return "Internato"
        case .enamed: return "ENAMED"
        case .residencia: return "Residência"
        case .revalida: return "Revalida"
        }
    }

    var icon: String {
        switch self {
        case .faculdade: return "graduationcap"
        case .internato: return "stethoscope"
        case .enamed: return "doc.text.fill"
        case .residencia: return "cross.case"
        case .revalida: return "globe.americas"
        }
    }
}

/// Configuração específica da jornada. Shape varia por journeyType.
/// Default: dicionário vazio quando ainda não preenchido pelo onboarding.
struct JourneyConfig: Codable, Equatable {
    // FACULDADE / INTERNATO
    var currentSemester: Int?
    var institution: String?
    var activeDisciplines: [String]?

    // REVALIDA
    var currentStage: RevalidaStage?
    var focusAreas: [String]?

    // RESIDENCIA
    var targetSpecialty: String?
    var targetInstitutions: [String]?

    // INTERNATO
    var currentRotation: String?

    // Universal
    var mainGoal: String?
}

enum RevalidaStage: String, Codable {
    case primeira = "PRIMEIRA"
    case segunda = "SEGUNDA"
}

/// Modo de organização do conteúdo (3 lentes).
/// Default por journeyType + uni.curriculumMethod, override pessoal sempre vence.
enum ContentOrganizationMode: String, Codable, CaseIterable {
    case tradicional = "tradicional"      // 96 disciplinas (Anatomia, Fisio, Cardio...)
    case pbl = "pbl"                      // 12 sistemas (Cardiovascular, Resp...)
    case greatAreas = "great-areas"       // 5 grandes áreas CNRM/Enare

    var displayName: String {
        switch self {
        case .tradicional: return "Tradicional"
        case .pbl: return "PBL"
        case .greatAreas: return "CNRM/Enare"
        }
    }

    var icon: String {
        switch self {
        case .tradicional: return "books.vertical"
        case .pbl: return "circle.hexagongrid"
        case .greatAreas: return "target"
        }
    }
}

struct UserJourney: Codable, Equatable {
    var journeyType: JourneyType
    var journeyConfig: JourneyConfig

    static let `default` = UserJourney(
        journeyType: .faculdade,
        journeyConfig: JourneyConfig()
    )
}
