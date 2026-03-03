import Foundation

// MARK: - OSCE Domain Models

struct OscePatientContext: Decodable {
    let name: String
    let age: Int
    let sex: String
    let chiefComplaint: String
    let vitalSigns: OsceVitalSigns
}

struct OsceVitalSigns: Decodable {
    let bp: String      // e.g. "120/80 mmHg"
    let hr: Int         // bpm
    let rr: Int         // respiratory rate
    let temp: Double    // Celsius
    let spo2: Int       // %
}

// MARK: - API Requests / Responses

struct OsceStartRequest: Encodable {
    let specialty: String
}

struct OsceStartResponse: Decodable {
    let attemptId: String
    let currentStep: Int
    let patientContext: OscePatientContext
    let prompt: String
}

struct OsceRespondRequest: Encodable {
    let response: String
}
