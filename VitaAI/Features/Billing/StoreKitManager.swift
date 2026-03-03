import StoreKit
import Foundation

// MARK: - StoreKitManager
/// @Observable singleton managing StoreKit 2 subscription lifecycle.
/// Handles product loading, purchase flow, restoration, and entitlement checks.
/// StoreKit 2 only — zero StoreKit 1 APIs.

@Observable
@MainActor
final class StoreKitManager {

    // MARK: - Product IDs

    static let monthlyProductID = "com.bymav.vitaai.monthly"
    static let annualProductID  = "com.bymav.vitaai.annual"
    static let allProductIDs: Set<String> = [monthlyProductID, annualProductID]

    // MARK: - Observable State

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var activeProductID: String? = nil
    private(set) var isPurchasing = false
    private(set) var isLoadingProducts = false
    private(set) var purchaseError: String? = nil

    // MARK: - Computed Helpers

    var annualProduct: Product?  { products.first { $0.id == Self.annualProductID } }
    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyProductID } }

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
            // Annual first — highlighted plan in UI
            products = fetched.sorted {
                $0.id == Self.annualProductID && $1.id != Self.annualProductID
            }
            await refreshSubscriptionStatus()
        } catch {
            purchaseError = "Não foi possível carregar os planos disponíveis."
        }
    }

    /// Launch App Store purchase sheet for the given product.
    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await refreshSubscriptionStatus()
                await transaction.finish()
            case .userCancelled:
                break   // silent — user tapped Cancel
            case .pending:
                break   // awaiting parental approval
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Ocorreu um erro ao processar o pagamento. Tente novamente."
        }
    }

    /// Restore previous purchases via AppStore.sync().
    func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            purchaseError = "Não foi possível restaurar as compras anteriores."
        }
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

    func clearError() { purchaseError = nil }

    // MARK: - Private

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            await refreshSubscriptionStatus()
            await transaction.finish()
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
