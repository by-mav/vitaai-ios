import Foundation

// MARK: - Apple IAP Verification Models
// Used by VitaAPI.verifyAppleReceipt() for server-side validation of StoreKit 2 transactions.

struct VerifyAppleReceiptRequest: Codable {
    let transactionId: String
    let productId: String
    let bundleId: String
}

struct VerifyAppleReceiptResponse: Codable {
    let ok: Bool
    let plan: String?
    let error: String?
}
