import Foundation

// MARK: - VitaAPI+MaterialFolders
//
// Endpoints da feature de material folders por disciplina (Apr 2026).
// Isolado em arquivo próprio pra não conflitar com edits paralelos em
// VitaAPI.swift e manter a section da feature contida.
//
// Backend: vita-web — material-folders helper + 5 routes.
// Defaults são auto-criadas no primeiro GET /api/subjects/{id}/folders.

extension VitaAPI {
    func listSubjectFolders(subjectId: String) async throws -> [MaterialFolder] {
        let resp: MaterialFolderListResponse = try await client.get("subjects/\(subjectId)/folders")
        return resp.folders
    }

    func createCustomFolder(
        subjectId: String,
        name: String,
        icon: String? = nil,
        color: String? = nil
    ) async throws -> MaterialFolder {
        let resp: MaterialFolderResponse = try await client.post(
            "subjects/\(subjectId)/folders",
            body: CreateMaterialFolderRequest(name: name, icon: icon, color: color)
        )
        return resp.folder
    }

    func updateFolder(
        id: String,
        name: String? = nil,
        icon: String? = nil,
        color: String? = nil,
        sortOrder: Int? = nil
    ) async throws -> MaterialFolder {
        let resp: MaterialFolderResponse = try await client.patch(
            "folders/\(id)",
            body: UpdateMaterialFolderRequest(name: name, icon: icon, color: color, sortOrder: sortOrder)
        )
        return resp.folder
    }

    func deleteFolder(id: String) async throws {
        try await client.delete("folders/\(id)")
    }

    func listFolderDocuments(folderId: String) async throws -> FolderDocumentsResponse {
        try await client.get("folders/\(folderId)/documents")
    }

    func moveDocumentToFolder(documentId: String, folderId: String?) async throws {
        let _: MoveDocumentResponse = try await client.post(
            "documents/\(documentId)/move",
            body: MoveDocumentRequest(folderId: folderId)
        )
    }

    func presignFolderUpload(
        folderId: String,
        fileName: String,
        contentType: String,
        size: Int? = nil
    ) async throws -> PresignFolderUploadResponse {
        try await client.post(
            "folders/\(folderId)/upload",
            body: PresignFolderUploadRequest(fileName: fileName, contentType: contentType, size: size)
        )
    }
}
