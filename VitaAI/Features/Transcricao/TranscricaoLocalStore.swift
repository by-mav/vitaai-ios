import Foundation

// MARK: - TranscricaoLocalStore
//
// Storage local pra gravações que o user optou por NÃO transcrever na nuvem
// ("modo rascunho"). m4a fica em Documents/audios/<uuid>.m4a, metadata em
// Documents/audios/index.json. User pode depois promover pra cloud (upload +
// /api/ai/transcribe) ou apagar.
//
// Gold standard: igual Apple Voice Memos — default local, cloud opcional.
// Aqui é o inverso (default cloud pros alunos), mas o switch existe.
//
// Persistência mínima: JSON index em disco. Zero dependência do backend.

struct LocalRecording: Codable, Identifiable {
    var id: String              // UUID gerado no device
    var title: String           // "Gravação DD/MM HH:MM"
    var fileName: String        // <id>.m4a
    var durationSeconds: Int    // elapsed real quando user parou
    var fileSize: Int           // bytes no disk
    var language: String        // pt, en, etc.
    var discipline: String?     // "Farmacologia" | nil
    var createdAt: Date
    /// Status do upload em background quando user gravou com
    /// `transcribeWithAI=true`. `nil` = rascunho puro (user escolheu só local);
    /// `"uploading"`/`"transcribing"`/`"summarizing"` = pipeline em voo;
    /// `"ready"` = pronto (entry já foi migrada pra cloud list, só ainda não
    /// foi deletada); `"failed"` = erro, user pode tentar de novo via menu.
    var cloudStatus: String?
    /// `studio_sources.id` do backend depois que o upload iniciou. Permite
    /// abrir detail screen e polling direto enquanto cloudStatus != "ready".
    var cloudSourceId: String?
}

@MainActor
final class TranscricaoLocalStore {
    static let shared = TranscricaoLocalStore()

    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "com.bymav.vitaai.local-recordings", qos: .utility)

    /// Root folder: `<Documents>/audios/`
    private var rootFolder: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("audios", isDirectory: true)
    }

    /// Index file: `<Documents>/audios/index.json`
    private var indexURL: URL {
        rootFolder.appendingPathComponent("index.json")
    }

    private init() {
        try? fm.createDirectory(at: rootFolder, withIntermediateDirectories: true)
    }

    // MARK: - CRUD

    /// Move a temporary m4a (vindo do AVAudioFile) pra pasta permanente do
    /// device e grava entry no index. Retorna o id da nova gravação local.
    func save(
        tempURL: URL,
        title: String,
        durationSeconds: Int,
        language: String,
        discipline: String?
    ) throws -> LocalRecording {
        let id = UUID().uuidString.lowercased()
        let fileName = "\(id).m4a"
        let finalURL = rootFolder.appendingPathComponent(fileName)

        // Move instead of copy — o m4a temp sai da pasta tmp do OS, que pode
        // ser apagada a qualquer momento.
        if fm.fileExists(atPath: finalURL.path) {
            try fm.removeItem(at: finalURL)
        }
        try fm.moveItem(at: tempURL, to: finalURL)

        let size = (try? fm.attributesOfItem(atPath: finalURL.path)[.size] as? Int) ?? 0

        let rec = LocalRecording(
            id: id,
            title: title,
            fileName: fileName,
            durationSeconds: durationSeconds,
            fileSize: size,
            language: language,
            discipline: discipline,
            createdAt: Date(),
            cloudStatus: nil,
            cloudSourceId: nil
        )

        var all = loadAll()
        all.insert(rec, at: 0)
        try writeIndex(all)
        return rec
    }

    /// Atualiza `cloudStatus` e `cloudSourceId` do rascunho enquanto o upload
    /// roda em background. UI re-renderiza via `loadLocalRecordings()` no VM.
    func updateCloudStatus(id: String, status: String?, sourceId: String? = nil) throws {
        var all = loadAll()
        guard let idx = all.firstIndex(where: { $0.id == id }) else { return }
        all[idx].cloudStatus = status
        if let sourceId { all[idx].cloudSourceId = sourceId }
        try writeIndex(all)
    }

    /// List all local recordings, sorted newest first.
    func loadAll() -> [LocalRecording] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let list = try? decoder.decode([LocalRecording].self, from: data) else { return [] }
        return list.sorted(by: { $0.createdAt > $1.createdAt })
    }

    /// Returns nil if the recording doesn't exist or the file is gone from disk.
    func fileURL(for id: String) -> URL? {
        guard let rec = loadAll().first(where: { $0.id == id }) else { return nil }
        let url = rootFolder.appendingPathComponent(rec.fileName)
        guard fm.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Rename a local recording (UX parity with cloud recordings).
    func rename(id: String, to newTitle: String) throws {
        var all = loadAll()
        guard let idx = all.firstIndex(where: { $0.id == id }) else { return }
        all[idx].title = newTitle
        try writeIndex(all)
    }

    /// Delete m4a + index entry. Irreversible.
    func delete(id: String) throws {
        var all = loadAll()
        guard let idx = all.firstIndex(where: { $0.id == id }) else { return }
        let rec = all.remove(at: idx)
        let url = rootFolder.appendingPathComponent(rec.fileName)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        try writeIndex(all)
    }

    /// Called when user taps "Transcrever agora" on a local card. Returns the
    /// local file URL so the caller can push it through the cloud pipeline,
    /// then invokes `delete(id:)` on success (caller's responsibility).
    func promote(id: String) -> URL? {
        fileURL(for: id)
    }

    // MARK: - Private

    private func writeIndex(_ list: [LocalRecording]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(list)
        try data.write(to: indexURL, options: .atomic)
    }
}
