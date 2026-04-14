import HealthKit
import Observation

@MainActor
@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    var isAuthorized = false

    // Data we want to read
    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(exercise) }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        return types
    }()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {}

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            return true
        } catch {
            print("[HealthKit] Auth failed: \(error)")
            return false
        }
    }

    // Fetch last N days of sleep data
    func fetchSleepData(days: Int = 7) async -> [SleepEntry] {
        guard isAvailable else { return [] }
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let entries = (samples as? [HKCategorySample])?.compactMap { sample -> SleepEntry? in
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    guard value == .asleepCore || value == .asleepDeep || value == .asleepREM || value == .asleepUnspecified else { return nil }
                    return SleepEntry(
                        start: sample.startDate,
                        end: sample.endDate,
                        hours: sample.endDate.timeIntervalSince(sample.startDate) / 3600,
                        stage: value?.stageName ?? "sleep"
                    )
                } ?? []
                continuation.resume(returning: entries)
            }
            store.execute(query)
        }
    }

    // Fetch last N days of steps
    func fetchSteps(days: Int = 7) async -> [StepsEntry] {
        guard isAvailable else { return [] }
        let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!

        var entries: [StepsEntry] = []
        for dayOffset in 0..<days {
            let day = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            let dayStart = Calendar.current.startOfDay(for: day)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd)

            let steps = await withCheckedContinuation { (continuation: CheckedContinuation<Double, Never>) in
                let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                    continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                }
                store.execute(query)
            }
            entries.append(StepsEntry(date: dayStart, count: Int(steps)))
        }
        return entries
    }

    // Fetch total exercise minutes for last N days
    func fetchExerciseMinutes(days: Int = 7) async -> Double {
        guard isAvailable else { return 0 }
        let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: exerciseType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: .minute()) ?? 0)
            }
            store.execute(query)
        }
    }
}

// MARK: - Models

struct SleepEntry: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let hours: Double
    let stage: String
}

struct StepsEntry: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

// MARK: - Extensions

extension HKCategoryValueSleepAnalysis {
    var stageName: String {
        switch self {
        case .asleepCore: return "core"
        case .asleepDeep: return "deep"
        case .asleepREM: return "rem"
        default: return "sleep"
        }
    }
}
