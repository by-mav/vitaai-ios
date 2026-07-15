import Foundation
import Observation

// MARK: - AppConfigService
// Fetches and caches GET /api/config/app.
// Cache strategy: UserDefaults with 1-hour TTL.
// Sem fallback numérico: o cliente guarda e mostra somente configuração recebida.
//
// Usage (async, from @MainActor context):
//   await AppConfigService.shared.loadIfNeeded(api: container.api)
//
@MainActor
@Observable
final class AppConfigService {

    // MARK: - Singleton
    static let shared = AppConfigService()

    // MARK: - State
    private(set) var config: AppConfigResponse?
    private(set) var isLoaded = false
    private(set) var lastError: Error?

    // MARK: - Cache keys
    private enum CacheKey {
        static let data = "AppConfigService.cachedData"
        static let timestamp = "AppConfigService.cachedAt"
    }
    private let ttl: TimeInterval = 3600 // 1 hour

    // MARK: - Init
    private init() {
        loadFromCache()
    }

    // MARK: - Public API

    /// Loads config from server if cache is stale or empty.
    /// Safe to call multiple times — no-op if fresh.
    func loadIfNeeded(api: VitaAPI) async {
        if isLoaded && !isCacheStale() { return }
        await fetch(api: api)
    }

    /// Force-refreshes from server regardless of cache age.
    func refresh(api: VitaAPI) async {
        await fetch(api: api)
    }

    // MARK: - Private

    private func fetch(api: VitaAPI) async {
        do {
            let fetched: AppConfigResponse = try await api.fetchAppConfig()
            config = fetched
            isLoaded = true
            lastError = nil
            saveToCache(fetched)
        } catch {
            // Keep existing config (cache or fallback) on network error
            lastError = error
            if !isLoaded {
                isLoaded = true // mark loaded so UI doesn't spin forever
            }
        }
    }

    // MARK: - Cache

    private func loadFromCache() {
        guard
            let data = UserDefaults.standard.data(forKey: CacheKey.data),
            let decoded = try? JSONDecoder().decode(AppConfigResponse.self, from: data)
        else { return }

        config = decoded
        isLoaded = true
    }

    private func saveToCache(_ config: AppConfigResponse) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: CacheKey.data)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: CacheKey.timestamp)
    }

    private func isCacheStale() -> Bool {
        let savedAt = UserDefaults.standard.double(forKey: CacheKey.timestamp)
        guard savedAt > 0 else { return true }
        return Date().timeIntervalSince1970 - savedAt > ttl
    }
}
