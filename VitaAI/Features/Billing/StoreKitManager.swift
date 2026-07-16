import StoreKit
import Foundation
import Observation

struct StoreKitVerifiedPurchase: Sendable {
    let transaction: Transaction
    let signedTransaction: String

    var transactionId: String { String(transaction.id) }
    var productId: String { transaction.productID }
}

// MARK: - StoreKitManager
/// @Observable singleton managing StoreKit 2 subscription lifecycle.
/// Handles product loading, purchase flow, restoration, and entitlement checks.
/// StoreKit 2 only — zero StoreKit 1 APIs.

@Observable
@MainActor
final class StoreKitManager {

    // MARK: - Product IDs
    // Both tiers are monthly. Premium = R$24,90/mes, Pro = R$49,90/mes.
    // 7-day free trial on both.

    static let premiumProductID = "com.bymav.vitaai.premium"
    static let proProductID     = "com.bymav.vitaai.pro"
    static let allProductIDs: Set<String> = [premiumProductID, proProductID]

    // MARK: - Observable State

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var activeProductID: String? = nil
    private(set) var isPurchasing = false
    private(set) var isLoadingProducts = false
    private(set) var purchaseError: String? = nil
    private(set) var purchaseNotice: String? = nil
    private(set) var isProEligibleForIntroOffer = false

    func isEligibleForIntroOffer(productID: String) -> Bool {
        products.contains { $0.id == productID && $0.subscription?.introductoryOffer != nil }
            && isProEligibleForIntroOffer
    }

    // MARK: - Computed Helpers

    var premiumProduct: Product? { products.first { $0.id == Self.premiumProductID } }
    var proProduct: Product?     { products.first { $0.id == Self.proProductID } }

    /// True if user has the Pro tier specifically.
    var isPro: Bool { activeProductID == Self.proProductID }

    /// True if user has Premium tier specifically (not Pro).
    var isPremium: Bool { activeProductID == Self.premiumProductID }

    // MARK: - Init

    init() {
        // Background transaction listener — exits naturally when self is deallocated.
        Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handleTransactionUpdate(result)
            }
        }
    }

    // MARK: - Public API

    /// Fetch products from App Store Connect. No-op if already loaded.
    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            print("[StoreKit] Loaded \(fetched.count) products: \(fetched.map { "\($0.id) = \($0.displayPrice)" })")
            guard !fetched.isEmpty else {
                purchaseError = String(localized: "billing_products_load_error")
                return
            }
            // Premium first (cheaper), Pro second
            products = fetched.sorted {
                $0.id == Self.premiumProductID && $1.id != Self.premiumProductID
            }
            purchaseError = nil
            purchaseNotice = nil
            if let subscription = proProduct?.subscription,
               subscription.introductoryOffer != nil {
                isProEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
            } else {
                isProEligibleForIntroOffer = false
            }
            await refreshSubscriptionStatus()
        } catch {
            purchaseError = String(localized: "billing_products_load_error")
        }
    }

    /// Launch App Store purchase sheet for the given product.
    @discardableResult
    func purchase(_ product: Product) async -> StoreKitVerifiedPurchase? {
        isPurchasing = true
        purchaseError = nil
        purchaseNotice = nil
        defer { isPurchasing = false }
        VitaAnalytics.capture(event: "checkout_started", properties: [
            "plan_id": product.id,
            "provider": "apple_iap",
            "price_brl": NSDecimalNumber(decimal: product.price).doubleValue,
        ])

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                print("[StoreKit] Purchase SUCCESS: \(transaction.productID)")
                VitaAnalytics.capture(event: "checkout_completed", properties: [
                    "plan_id": transaction.productID,
                    "transaction_id": String(transaction.id),
                    "provider": "apple_iap",
                ])
                await refreshSubscriptionStatus()
                return StoreKitVerifiedPurchase(
                    transaction: transaction,
                    signedTransaction: verification.jwsRepresentation
                )
            case .userCancelled:
                VitaAnalytics.capture(event: "checkout_failed", properties: [
                    "plan_id": product.id,
                    "reason": "user_cancelled",
                ])
                return nil   // silent — user tapped Cancel
            case .pending:
                purchaseNotice = String(localized: "billing_purchase_pending")
                return nil
            @unknown default:
                return nil
            }
        } catch {
            purchaseError = String(localized: "billing_purchase_error")
            VitaAnalytics.capture(event: "checkout_failed", properties: [
                "plan_id": product.id,
                "reason": error.localizedDescription,
            ])
            return nil
        }
    }

    /// Restore previous purchases via AppStore.sync().
    @discardableResult
    func restorePurchases() async -> [StoreKitVerifiedPurchase] {
        isPurchasing = true
        purchaseError = nil
        purchaseNotice = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            let purchases = await activePurchases()
            if purchases.isEmpty {
                purchaseNotice = String(localized: "billing_restore_none")
            }
            return purchases
        } catch {
            purchaseError = String(localized: "billing_restore_error")
            return []
        }
    }

    func activePurchases() async -> [StoreKitVerifiedPurchase] {
        var purchases: [StoreKitVerifiedPurchase] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  Self.allProductIDs.contains(transaction.productID) else { continue }
            purchases.append(
                StoreKitVerifiedPurchase(
                    transaction: transaction,
                    signedTransaction: result.jwsRepresentation
                )
            )
        }
        return purchases
    }

    /// Check current entitlements and update isSubscribed / activeProductID.
    func refreshSubscriptionStatus() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result,
                  tx.revocationDate == nil,
                  Self.allProductIDs.contains(tx.productID) else { continue }
            isSubscribed = true
            activeProductID = tx.productID
            found = true
            break
        }
        if !found {
            isSubscribed = false
            activeProductID = nil
        }
    }

    func clearError() {
        purchaseError = nil
        purchaseNotice = nil
    }

    // MARK: - Private

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            await refreshSubscriptionStatus()
            _ = transaction
        } catch {
            // Ignore unverified transactions
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreKitManagerError.failedVerification
        case .verified(let value): return value
        }
    }
}

// MARK: - Errors

enum StoreKitManagerError: Error, LocalizedError {
    case failedVerification

    var errorDescription: String? {
        "Não foi possível verificar a compra com a App Store."
    }
}
