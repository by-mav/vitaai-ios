import Foundation
import SwiftUI

// MARK: - ProvasViewModel
// Mirrors Android: ui/screens/provas/ProvasViewModel.kt

private let pendingStatuses: Set<String> = ["pending", "processing"]

@MainActor
@Observable
final class ProvasViewModel {
    private(set) var selectedTab: Int = 0  // 0=Upload, 1=Professores, 2=Provas
    private(set) var professors: [CrowdProfessor] = []
    private(set) var exams: [CrowdExamEntry] = []
    private(set) var uploads: [CrowdUploadRecord] = []
    private(set) var selectedExam: CrowdExamDetail? = nil
    private(set) var isLoading: Bool = false
    private(set) var isUploading: Bool = false
    private(set) var uploadError: String? = nil
    private(set) var error: String? = nil

    /// Images selected by the user, represented as (Data, filename, mimeType).
    private(set) var pendingImages: [(Data, String, String)] = []
    private(set) var pendingImageCount: Int = 0  // tracks count for UI display

    private let api: VitaAPI
    private nonisolated(unsafe) var pollTask: Task<Void, Never>? = nil

    deinit {
        pollTask?.cancel()
    }

    init(api: VitaAPI) {
        self.api = api
    }

    // MARK: - Initial Load

    func loadAll() async {
        async let p: () = loadProfessorsInternal()
        async let e: () = loadExamsInternal()
        async let u: () = loadUploadsInternal()
        _ = await (p, e, u)
    }

    // MARK: - Tab

    func selectTab(_ tab: Int) {
        selectedTab = tab
        error = nil
        uploadError = nil
    }

    // MARK: - Professors

    func loadProfessors() {
        Task { @MainActor [weak self] in
            await self?.loadProfessorsInternal()
        }
    }

    private func loadProfessorsInternal() async {
        isLoading = true
        error = nil
        do {
            professors = try await api.getCrowdProfessors()
        } catch {
            self.error = "Erro ao carregar professores"
            print("[ProvasVM] loadProfessors failed: \(error)")
        }
        isLoading = false
    }

    // MARK: - Exams

    func loadExams() {
        Task { @MainActor [weak self] in
            await self?.loadExamsInternal()
        }
    }

    private func loadExamsInternal() async {
        isLoading = true
        error = nil
        do {
            exams = try await api.getCrowdExams()
        } catch {
            self.error = "Erro ao carregar provas"
            print("[ProvasVM] loadExams failed: \(error)")
        }
        isLoading = false
    }

    func loadExamDetail(_ examId: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isLoading = true
            self.error = nil
            do {
                self.selectedExam = try await self.api.getCrowdExamDetail(examId)
            } catch {
                self.error = "Erro ao carregar detalhes da prova"
                print("[ProvasVM] loadExamDetail(\(examId)) failed: \(error)")
            }
            self.isLoading = false
        }
    }

    func clearSelectedExam() {
        selectedExam = nil
    }

    // MARK: - Uploads

    func loadUploads() {
        Task { @MainActor [weak self] in
            await self?.loadUploadsInternal()
        }
    }

    private func loadUploadsInternal() async {
        do {
            uploads = try await api.getCrowdUploads()
            schedulePollingIfNeeded(uploads)
        } catch {
            print("[ProvasVM] loadUploads failed: \(error)")
        }
    }

    // MARK: - Image Selection

    /// Called by the view when the user picks images from PhotosPicker.
    /// `images`: array of (Data, filename, mimeType)
    func setPendingImages(_ images: [(Data, String, String)]) {
        pendingImages = images
        pendingImageCount = images.count
        uploadError = nil
    }

    func clearPendingImages() {
        pendingImages = []
        pendingImageCount = 0
        uploadError = nil
    }

    // MARK: - Upload

    func uploadImages() async {
        guard !pendingImages.isEmpty else { return }
        isUploading = true
        uploadError = nil
        do {
            let response = try await api.uploadExamImages(pendingImages)
            print("[ProvasVM] Upload OK: uploadId=\(response.uploadId), status=\(response.status)")
            pendingImages = []
            pendingImageCount = 0
            // Refresh history and start polling
            await loadUploadsInternal()
        } catch {
            uploadError = "Erro ao enviar imagens: \(error.localizedDescription)"
            print("[ProvasVM] uploadImages failed: \(error)")
        }
        isUploading = false
    }

    // MARK: - Polling for upload status

    private func schedulePollingIfNeeded(_ currentUploads: [CrowdUploadRecord]) {
        let hasPending = currentUploads.contains { pendingStatuses.contains($0.status) }
        guard hasPending else {
            pollTask?.cancel()
            pollTask = nil
            return
        }
        guard pollTask == nil || pollTask?.isCancelled == true else { return }

        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let maxAttempts = 60 // 60 × 3s = 3 minutes max
            var attempt = 0
            while !Task.isCancelled && attempt < maxAttempts {
                attempt += 1
                try? await Task.sleep(for: .milliseconds(3_000))
                guard !Task.isCancelled else { break }
                do {
                    let fresh = try await self.api.getCrowdUploads()
                    self.uploads = fresh
                    if !fresh.contains(where: { pendingStatuses.contains($0.status) }) {
                        // All done — refresh exam list if any completed
                        if fresh.contains(where: { $0.status == "completed" }) {
                            await self.loadExamsInternal()
                        }
                        break
                    }
                } catch {
                    print("[ProvasVM] poll failed: \(error)")
                    break
                }
            }
            self.pollTask = nil
        }
    }

    func clearError() {
        error = nil
        uploadError = nil
    }
}
