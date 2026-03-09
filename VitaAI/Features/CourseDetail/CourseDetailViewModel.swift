import Foundation
import SwiftUI

// MARK: - ModuleGroup
// Mirrors Android: CourseDetailViewModel.ModuleGroup

struct ModuleGroup: Identifiable {
    var id: String { "\(position)-\(name)" }
    let name: String
    let position: Int
    let files: [CanvasFile]
}

// MARK: - CourseDetailViewModel
// Mirrors Android: ui/screens/coursedetail/CourseDetailViewModel.kt

@MainActor
@Observable
final class CourseDetailViewModel {
    private(set) var course: Course? = nil
    private(set) var files: [CanvasFile] = []
    private(set) var assignments: [Assignment] = []
    private(set) var selectedTab: Int = 0  // 0=Arquivos, 1=Tarefas
    private(set) var downloadingFileId: String? = nil
    private(set) var downloadedFilePaths: [String: URL] = [:]
    private(set) var isLoading: Bool = true
    private(set) var error: String? = nil

    private let api: VitaAPI
    let courseId: String

    init(api: VitaAPI, courseId: String) {
        self.api = api
        self.courseId = courseId
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        error = nil
        do {
            async let coursesTask     = api.getCourses()
            async let filesTask       = api.getFiles(courseId: courseId)
            async let assignmentsTask = api.getAssignments(courseId: courseId)

            let (coursesResp, filesResp, assignmentsResp) =
                try await (coursesTask, filesTask, assignmentsTask)

            course      = coursesResp.courses.first { $0.id == courseId }
            files       = filesResp.files
            assignments = assignmentsResp.assignments
        } catch {
            self.error = error.localizedDescription
            // Seed mock so UI is not empty
            loadMock()
        }
        isLoading = false
    }

    func selectTab(_ index: Int) {
        selectedTab = index
    }

    // MARK: - File Grouping
    // Mirrors Android: groupedFiles() — groups by moduleName/modulePosition, rest unorganized

    func groupedFiles() -> (modules: [ModuleGroup], unorganized: [CanvasFile]) {
        var moduleMap: [String: [CanvasFile]] = [:]
        var positionMap: [String: Int] = [:]
        var unorganized: [CanvasFile] = []

        for file in files {
            if let moduleName = file.moduleName, let modulePos = file.modulePosition {
                let key = "\(modulePos)-\(moduleName)"
                moduleMap[key, default: []].append(file)
                positionMap[key] = modulePos
            } else {
                unorganized.append(file)
            }
        }

        let modules: [ModuleGroup] = moduleMap.map { key, groupFiles in
            let name = key.drop(while: { $0 != "-" }).dropFirst().description
            let pos  = positionMap[key] ?? 0
            return ModuleGroup(
                name: name,
                position: pos,
                files: groupFiles.sorted { ($0.itemPosition ?? 0) < ($1.itemPosition ?? 0) }
            )
        }
        .sorted { $0.position < $1.position }

        return (modules, unorganized)
    }

    // MARK: - PDF Download

    func downloadFile(fileId: String, fileName: String) async -> URL? {
        guard downloadingFileId == nil else { return nil }
        if let cached = downloadedFilePaths[fileId] { return cached }

        downloadingFileId = fileId
        defer { downloadingFileId = nil }

        do {
            let data = try await api.downloadFileData(fileId: fileId)
            let dir  = FileManager.default.temporaryDirectory
                .appendingPathComponent("pdfs", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(fileName)
            try data.write(to: dest)
            downloadedFilePaths[fileId] = dest
            return dest
        } catch {
            print("[CourseDetailVM] Download failed: \(error)")
            return nil
        }
    }

    // MARK: - Mock Seed

    private func loadMock() {
        course = Course(
            id: courseId,
            name: "Cardiologia Clínica",
            code: "CM-101",
            term: "2026/1",
            filesCount: 3,
            assignmentsCount: 2
        )

        files = [
            CanvasFile(id: "f1", displayName: "Harrison Cap. 12.pdf",
                       contentType: "application/pdf", size: 2_400_000,
                       hasText: true, totalPages: 28,
                       moduleName: "Módulo 1", modulePosition: 1, itemPosition: 0),
            CanvasFile(id: "f2", displayName: "Diretriz ICC 2024.pdf",
                       contentType: "application/pdf", size: 1_100_000,
                       hasText: false, totalPages: 14,
                       moduleName: "Módulo 1", modulePosition: 1, itemPosition: 1),
            CanvasFile(id: "f3", displayName: "Slides Aula 3.pptx",
                       contentType: "application/vnd.ms-powerpoint", size: 800_000,
                       hasText: false, totalPages: nil,
                       moduleName: "Módulo 2", modulePosition: 2, itemPosition: 0),
        ]

        assignments = [
            Assignment(id: "a1", name: "Resenha: mecanismos de ICC",
                       description: nil,
                       dueAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400 * 5)),
                       pointsPossible: 10, courseName: "Cardiologia Clínica", courseId: courseId),
            Assignment(id: "a2", name: "Prova Teórica — Unidade 2",
                       description: nil,
                       dueAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400 * 12)),
                       pointsPossible: 20, courseName: "Cardiologia Clínica", courseId: courseId),
        ]
    }
}
