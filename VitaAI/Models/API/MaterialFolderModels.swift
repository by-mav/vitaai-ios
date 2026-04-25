import Foundation

// MARK: - MaterialFolder
//
// Pasta de materiais por disciplina. 8 defaults auto-criadas quando a
// academic_subject nasce: slides / provas / transcricoes / plano-ensino /
// mapas-mentais / briefings / casos-clinicos / outros. Custom folders
// criadas pelo user via POST /api/subjects/{id}/folders.
//
// Source of truth: backend `vita.material_folders` (migration 0064) +
// openapi.yaml. Endpoints: subjects/{id}/folders, folders/{id},
// folders/{id}/documents, folders/{id}/upload, documents/{id}/move.

struct MaterialFolder: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    /// Slug imutável. Defaults: slides/provas/transcricoes/plano-ensino/
    /// mapas-mentais/briefings/casos-clinicos/outros. Customs: "custom-<uuid>".
    let slug: String
    /// SF Symbol name. Backend speaks semantics, client maps to icons.
    let icon: String
    /// Hex color (#FFB347). Optional — defaults inherit gold scale.
    let color: String?
    /// "default" | "custom". Defaults bloqueiam DELETE (rename só).
    let kind: String
    let sortOrder: Int
    let docCount: Int

    var isDefault: Bool { kind == "default" }
    var isCustom: Bool { kind == "custom" }
}

struct MaterialFolderListResponse: Codable {
    let folders: [MaterialFolder]
}

struct MaterialFolderResponse: Codable {
    let folder: MaterialFolder
}

struct CreateMaterialFolderRequest: Codable {
    let name: String
    let icon: String?
    let color: String?
}

struct UpdateMaterialFolderRequest: Codable {
    let name: String?
    let icon: String?
    let color: String?
    let sortOrder: Int?
}

struct FolderDocumentsResponse: Codable {
    let folder: FolderHeader
    let documents: [VitaDocument]

    struct FolderHeader: Codable {
        let id: String
        let name: String
        let slug: String
        let icon: String
    }
}

struct MoveDocumentRequest: Codable {
    let folderId: String?
}

struct MoveDocumentResponse: Codable {
    let document: MovedDocument

    struct MovedDocument: Codable {
        let id: String
        let folderId: String?
    }
}

struct PresignFolderUploadRequest: Codable {
    let fileName: String
    let contentType: String
    let size: Int?
}

struct PresignFolderUploadResponse: Codable {
    let documentId: String
    let folderId: String
    let uploadUrl: String
    let key: String
    let expiresInSeconds: Int
}
