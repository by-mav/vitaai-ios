import Foundation
import SwiftUI

// MARK: - SubscriptionStatusProvider
// Observable singleton that any screen can read to gate premium features.
// Injected via EnvironmentKey so children don't need AppContainer directly.
//
// Usage in any view:
//   @Environment(\.subscriptionStatus) private var subStatus
//   if subStatus.isPro { ... }

@Observable
@MainActor
final class SubscriptionStatusProvider {
    private(set) var isPro: Bool = false
    private(set) var plan: String = "free"
    private(set) var periodEnd: String? = nil
    private(set) var isLoaded: Bool = false

    private let api: VitaAPI
    private let storeKit: StoreKitManager

    init(api: VitaAPI) {
        self.api = api
        self.storeKit = StoreKitManager()
    }

    func refresh() async {
        await syncAppleEntitlements()
        do {
            let status = try await api.getBillingStatus()
            isPro = status.isActive && status.plan != "free"
            plan = status.plan
            periodEnd = status.periodEnd
            isLoaded = true
        } catch {
            // Network error — preserve current state, do not reset to false
            // (give user benefit of the doubt if offline)
            isLoaded = true
        }
    }

    /// Reconciles current StoreKit entitlements with the backend on every app
    /// launch/foreground. This covers renewals and restored purchases even when
    /// they happened while the paywall was not on screen.
    private func syncAppleEntitlements() async {
        for purchase in await storeKit.activePurchases() {
            do {
                let response = try await api.verifyAppleReceipt(
                    transactionId: purchase.transactionId,
                    productId: purchase.productId,
                    signedTransaction: purchase.signedTransaction
                )
                if response.ok {
                    await purchase.transaction.finish()
                }
            } catch {
                // Keep the transaction unfinished so StoreKit can redeliver it
                // after a temporary network/backend failure.
            }
        }
    }
}

// MARK: - Environment Key

private struct SubscriptionStatusKey: EnvironmentKey {
    @MainActor static let defaultValue: SubscriptionStatusProvider = SubscriptionStatusProvider(
        api: VitaAPI(client: HTTPClient(tokenStore: TokenStore()))
    )
}

extension EnvironmentValues {
    var subscriptionStatus: SubscriptionStatusProvider {
        get { self[SubscriptionStatusKey.self] }
        set { self[SubscriptionStatusKey.self] = newValue }
    }
}
