import Foundation

// MIGRATION: Billing models — partial migration to OpenAPI generated types
// CheckoutResponse → CreateCheckoutSession200Response (generated)
// CheckoutRequest → CreateCheckoutSessionRequest (generated)
// BillingStatus and VerifyApple* have no generated equivalents — kept manual

typealias CheckoutResponse = CreateCheckoutSession200Response
typealias CheckoutRequest = CreateCheckoutSessionRequest

// MARK: - Billing Status (no generated equivalent)

struct BillingStatus: Decodable {
    let plan: String
    let isActive: Bool
    let periodEnd: String?
}

// MARK: - Apple IAP Verification Models (no generated equivalent)

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
