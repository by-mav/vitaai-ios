import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    private let tokenStore: TokenStore
    private let draftKey = "vita_onboarding_draft_v3"
    private var isRestoringDraft = false
    private var pendingUniversityID: String?
    private var requestedUniversityCity: String?
    private var requestedUniversityState: String?
    var api: VitaAPI?

    // MARK: - Navigation

    var isSaving = false

    // MARK: - Identity and university

    var nickname: String = "" { didSet { persistDraft() } }
    var universityQuery: String = "" { didSet { persistDraft() } }
    var selectedUniversity: University? {
        didSet {
            pendingUniversityID = selectedUniversity?.id
            persistDraft()
        }
    }
    var selectedSemester = 0 { didSet { persistDraft() } }
    var allUniversities: [University] = []

    // MARK: - Journey branch

    var academicPhase: AcademicPhase? {
        didSet {
            guard !isRestoringDraft, academicPhase != oldValue else {
                persistDraft()
                return
            }

            // A phase is the root branch. Changing it invalidates all answers
            // from the previous branch before the next screen is rendered.
            inFaculdade = academicPhase?.derivedInFaculdade
            selectedGoal = academicPhase?.automaticGoal
            revalidaStage = nil
            revalidaFocusAreas = []
            targetSpecialtySlug = nil
            targetInstitutions = []
            selectedUniversity = nil
            universityQuery = ""
            requestedUniversityCity = nil
            requestedUniversityState = nil
            selectedSemester = 0
            activeSyncId = nil
            syncedSubjects = []
            subjectDifficulties = [:]
            persistDraft()
        }
    }

    var inFaculdade: InFaculdadeStatus? { didSet { persistDraft() } }
    var selectedGoal: OnboardingGoal? {
        didSet {
            if !isRestoringDraft, academicPhase == .other {
                inFaculdade = selectedGoal == .faculdade
                    ? .notStarted
                    : (selectedGoal == nil ? nil : .graduated)
            }
            persistDraft()
        }
    }
    var revalidaStage: RevalidaStage? { didSet { persistDraft() } }
    var revalidaFocusAreas: [String] = [] { didSet { persistDraft() } }
    var targetSpecialtySlug: String? { didSet { persistDraft() } }
    var targetInstitutions: [String] = [] { didSet { persistDraft() } }

    // MARK: - Sync

    var activeSyncId: String? { didSet { persistDraft() } }
    var syncedSubjects: [SyncedSubject] = [] { didSet { persistDraft() } }
    var syncGrades = 0 { didSet { persistDraft() } }
    var syncSchedule = 0 { didSet { persistDraft() } }
    var syncCourses = 0 { didSet { persistDraft() } }
    var subjectDifficulties: [String: String] = [:] { didSet { persistDraft() } }

    // MARK: - Derived

    var filteredUniversities: [University] {
        let query = universityQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return allUniversities.filter { university in
            university.name.lowercased().contains(query)
                || university.shortName.lowercased().contains(query)
                || university.city.lowercased().contains(query)
        }
    }

    var allPortalTypes: [PortalTypeInfo] {
        var seen = Set<String>()
        var result: [PortalTypeInfo] = []
        for university in allUniversities {
            if let portals = university.portals {
                for portal in portals
                    where !portal.portalType.isEmpty && !seen.contains(portal.portalType) {
                    seen.insert(portal.portalType)
                    result.append(PortalTypeInfo(type: portal.portalType))
                }
            }
        }
        return result.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Init

    init(tokenStore: TokenStore, api: VitaAPI? = nil) {
        self.tokenStore = tokenStore
        self.api = api
        restoreDraft()

        Task {
            if self.nickname.isEmpty,
               let name = await tokenStore.userName,
               !name.isEmpty {
                self.nickname = name.split(separator: " ").first.map(String.init) ?? name
            }
        }
    }

    func loadUniversities() async {
        guard let api else { return }
        do {
            let response = try await api.getUniversities()
            allUniversities = response.universities
            restoreSelectedUniversityIfPossible()
        } catch {
            try? await Task.sleep(for: .seconds(2))
            if let response = try? await api.getUniversities() {
                allUniversities = response.universities
                restoreSelectedUniversityIfPossible()
            }
        }
    }

    // MARK: - Answers

    func selectAcademicPhase(_ phase: AcademicPhase) {
        academicPhase = phase
    }

    func selectUniversity(_ university: University) {
        if !university.id.hasPrefix("requested-") {
            requestedUniversityCity = nil
            requestedUniversityState = nil
        }
        selectedUniversity = university
        universityQuery = university.shortName
    }

    func selectRequestedUniversity(name: String, city: String, state: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug = trimmedName
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: .current
            )
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { result, character in
                if character != "-" || result.last != "-" {
                    result.append(character)
                }
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        requestedUniversityCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        requestedUniversityState = state
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        selectUniversity(
            University(
                id: "requested-\(slug)",
                name: trimmedName,
                shortName: trimmedName,
                city: requestedUniversityCity ?? "",
                state: requestedUniversityState ?? "",
                enameConcept: nil,
                portals: []
            )
        )
    }

    func clearUniversity() {
        selectedUniversity = nil
        universityQuery = ""
    }

    func selectSemester(_ semester: Int) {
        selectedSemester = semester
    }

    func setDifficulty(_ subject: String, difficulty: String) {
        subjectDifficulties[subject] = difficulty
    }

    func setSyncId(_ syncId: String) {
        activeSyncId = syncId
    }

    // MARK: - Sync results

    func fetchSubjectsFromAPI() async {
        guard let api else { return }

        do {
            let gradesResponse = try await api.getGradesCurrent()
            let subjects = gradesResponse.current + gradesResponse.completed
            let names = Set(subjects.map(\.subjectName).filter { !$0.isEmpty }).sorted()
            if !names.isEmpty {
                syncedSubjects = names.map { SyncedSubject(name: $0, source: "portal") }
                syncGrades = subjects.count
                return
            }
        } catch {
            print("[Onboarding] Portal grades fetch failed: \(error)")
        }

        do {
            let agenda = try await api.getAgenda()
            let names = Set(agenda.schedule.map(\.subjectName).filter { !$0.isEmpty }).sorted()
            if !names.isEmpty {
                syncedSubjects = names.map { SyncedSubject(name: $0, source: "portal") }
            }
        } catch {
            print("[Onboarding] Agenda fetch failed: \(error)")
        }
    }

    // MARK: - Final save

    func complete() async {
        isSaving = true
        let subjects = syncedSubjects.map(\.name)
        let data = OnboardingData(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            universityName: selectedUniversity?.shortName ?? "",
            universityState: selectedUniversity?.state ?? "",
            semester: selectedSemester,
            subjects: subjects,
            subjectDifficulties: subjectDifficulties
        )

        AnalyticsTracker.shared.event(.onboardingCompleted, properties: [
            "university_name": data.universityName,
            "semester": data.semester,
            "disciplines_count": subjects.count,
            "portal_connected": !syncedSubjects.isEmpty,
            "academic_phase": academicPhase?.rawValue ?? "n/a",
            "goal": selectedGoal?.rawValue ?? "legacy",
            "in_faculdade": inFaculdade?.rawValue ?? "n/a",
        ])
        await tokenStore.saveOnboardingData(data)

        let didSyncBackend: Bool
        if selectedGoal != nil {
            didSyncBackend = await postOnboardingV2ToBackend(data: data)
        } else {
            didSyncBackend = await postOnboardingToBackend(data: data)
        }

        // Local completion remains available offline, but the durable answers
        // are only discarded after the canonical backend accepted them.
        if didSyncBackend { clearDraft() }
        isSaving = false
    }

    // MARK: - Durable draft

    /// The backend endpoint is a finalizing write: it marks onboarding
    /// complete. Until that moment, every answer is encoded locally after the
    /// mutation so an app kill resumes the exact branch with no data loss.
    private func persistDraft() {
        guard !isRestoringDraft else { return }
        let draft = OnboardingDraft(
            nickname: nickname,
            universityQuery: universityQuery,
            selectedUniversityID: selectedUniversity?.id ?? pendingUniversityID,
            requestedUniversityCity: requestedUniversityCity,
            requestedUniversityState: requestedUniversityState,
            selectedSemester: selectedSemester,
            academicPhase: academicPhase?.rawValue,
            inFaculdade: inFaculdade?.rawValue,
            selectedGoal: selectedGoal?.rawValue,
            revalidaStage: revalidaStage?.rawValue,
            revalidaFocusAreas: revalidaFocusAreas,
            targetSpecialtySlug: targetSpecialtySlug,
            targetInstitutions: targetInstitutions,
            activeSyncId: activeSyncId,
            syncedSubjects: syncedSubjects.map {
                OnboardingDraft.DraftSubject(name: $0.name, source: $0.source)
            },
            syncGrades: syncGrades,
            syncSchedule: syncSchedule,
            syncCourses: syncCourses,
            subjectDifficulties: subjectDifficulties
        )
        guard let encoded = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(encoded, forKey: draftKey)
    }

    private func restoreDraft() {
        guard let data = UserDefaults.standard.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data) else { return }

        isRestoringDraft = true
        nickname = draft.nickname
        universityQuery = draft.universityQuery
        pendingUniversityID = draft.selectedUniversityID
        requestedUniversityCity = draft.requestedUniversityCity
        requestedUniversityState = draft.requestedUniversityState
        selectedSemester = draft.selectedSemester
        academicPhase = draft.academicPhase.flatMap { AcademicPhase(rawValue: $0) }
        inFaculdade = draft.inFaculdade.flatMap { InFaculdadeStatus(rawValue: $0) }
        selectedGoal = draft.selectedGoal.flatMap { OnboardingGoal(rawValue: $0) }
        revalidaStage = draft.revalidaStage.flatMap { RevalidaStage(rawValue: $0) }
        revalidaFocusAreas = draft.revalidaFocusAreas
        targetSpecialtySlug = draft.targetSpecialtySlug
        targetInstitutions = draft.targetInstitutions
        activeSyncId = draft.activeSyncId
        syncedSubjects = draft.syncedSubjects.map {
            SyncedSubject(name: $0.name, source: $0.source)
        }
        syncGrades = draft.syncGrades
        syncSchedule = draft.syncSchedule
        syncCourses = draft.syncCourses
        subjectDifficulties = draft.subjectDifficulties
        isRestoringDraft = false
    }

    private func restoreSelectedUniversityIfPossible() {
        guard let pendingUniversityID else { return }
        if let university = allUniversities.first(where: { $0.id == pendingUniversityID }) {
            selectedUniversity = university
            return
        }
        if pendingUniversityID.hasPrefix("requested-"), !universityQuery.isEmpty {
            selectedUniversity = University(
                id: pendingUniversityID,
                name: universityQuery,
                shortName: universityQuery,
                city: requestedUniversityCity ?? "",
                state: requestedUniversityState ?? "",
                enameConcept: nil,
                portals: []
            )
        }
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }

    // MARK: - Backend sync

    private func postOnboardingToBackend(data: OnboardingData) async -> Bool {
        guard let api else {
            print("[OnboardingVM] No API available to post onboarding data")
            return false
        }

        let body = OnboardingPostRequest(
            moment: "graduacao",
            studyGoal: "graduacao",
            year: data.semester > 0 ? data.semester : nil,
            selectedSubjects: data.subjects.isEmpty ? nil : data.subjects,
            subjectDifficulties: data.subjectDifficulties.isEmpty ? nil : data.subjectDifficulties
        )

        do {
            try await api.postOnboarding(body)
            return true
        } catch {
            print("[OnboardingVM] Failed to post onboarding data: \(error.localizedDescription)")
            return false
        }
    }

    private func postOnboardingV2ToBackend(data: OnboardingData) async -> Bool {
        guard let api else {
            print("[OnboardingVM] No API available to post onboarding v2 data")
            return false
        }
        guard let goal = selectedGoal else {
            print("[OnboardingVM] postOnboardingV2 called without selectedGoal")
            return false
        }

        let semesterValue = inFaculdade == .yes && selectedSemester > 0 ? selectedSemester : nil
        let universityName = inFaculdade == .yes ? selectedUniversity?.shortName : nil
        let selectedUniversityID = selectedUniversity?.id
        let isLocalUniversity = selectedUniversityID?.hasPrefix("local-") == true
            || selectedUniversityID?.hasPrefix("requested-") == true
        let universityID = inFaculdade == .yes && !isLocalUniversity
            ? selectedUniversityID
            : nil
        let universityLMS = inFaculdade == .yes
            ? selectedUniversity?.primaryPortal?.portalType
            : nil
        let subjects = data.subjects.isEmpty ? nil : data.subjects

        let body = OnboardingV2Request(
            goal: goal.rawValue,
            inFaculdade: inFaculdade?.rawValue,
            semester: semesterValue,
            university: universityName,
            universityId: universityID,
            universityLms: universityLMS,
            selectedSubjects: subjects,
            studyGoal: nil,
            targetSpecialty: targetSpecialtySlug,
            targetInstitutions: targetInstitutions.isEmpty ? nil : targetInstitutions,
            currentStage: revalidaStage?.rawValue,
            focusAreas: revalidaFocusAreas.isEmpty ? nil : revalidaFocusAreas
        )

        do {
            _ = try await api.postOnboardingV2(body)
            return true
        } catch {
            print("[OnboardingVM] Failed to post onboarding v2 data: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Journey choices

enum OnboardingGoal: String, CaseIterable, Hashable {
    case faculdade = "FACULDADE"
    case enamed = "ENAMED"
    case residencia = "RESIDENCIA"
    case revalida = "REVALIDA"
}

enum InFaculdadeStatus: String, Hashable {
    case notStarted = "not_started"
    case yes
    case graduated
}

enum AcademicPhase: String, Hashable, CaseIterable {
    case vestibulando
    case graduando
    case residencia
    case professional
    case other

    var derivedInFaculdade: InFaculdadeStatus? {
        switch self {
        case .vestibulando: return .notStarted
        case .graduando: return .yes
        case .residencia, .professional: return .graduated
        case .other: return nil
        }
    }

    var automaticGoal: OnboardingGoal? {
        switch self {
        case .vestibulando: return .faculdade
        case .residencia: return .residencia
        case .graduando, .professional, .other: return nil
        }
    }
}

// MARK: - Draft models

struct SyncedSubject: Identifiable {
    var id: String { name }
    let name: String
    let source: String
}

private struct OnboardingDraft: Codable {
    struct DraftSubject: Codable {
        let name: String
        let source: String
    }

    let nickname: String
    let universityQuery: String
    let selectedUniversityID: String?
    let requestedUniversityCity: String?
    let requestedUniversityState: String?
    let selectedSemester: Int
    let academicPhase: String?
    let inFaculdade: String?
    let selectedGoal: String?
    let revalidaStage: String?
    let revalidaFocusAreas: [String]
    let targetSpecialtySlug: String?
    let targetInstitutions: [String]
    let activeSyncId: String?
    let syncedSubjects: [DraftSubject]
    let syncGrades: Int
    let syncSchedule: Int
    let syncCourses: Int
    let subjectDifficulties: [String: String]
}
