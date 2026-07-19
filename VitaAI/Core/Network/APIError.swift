import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case forbidden
    case consentRequired
    case serverError(Int)
    case conflict(status: Int, body: Data)
    case decodingError(Error)
    case networkError(Error)
    case noData
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .unauthorized:
            return "Sessão expirada. Faça login novamente."
        case .forbidden:
            return "Recurso disponível apenas para assinantes Pro."
        case .consentRequired:
            return "Ative o Chat IA para continuar."
        case .serverError(let code):
            return "Erro no servidor (\(code))"
        case .conflict:
            return "Conflito com um recurso existente"
        case .decodingError:
            return "Erro ao processar resposta"
        case .networkError(let error):
            return "Erro de conexão: \(error.localizedDescription)"
        case .noData:
            return "Nenhum dado recebido"
        case .unknown:
            return "Erro desconhecido"
        }
    }
}
