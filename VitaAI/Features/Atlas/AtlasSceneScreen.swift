import SwiftUI
import SceneKit
import GLTFKit2
import Sentry
import OSLog

// MARK: - Atlas 3D — Native SceneKit screen
//
// Replaces the old WKWebView approach that loaded /atlas-embed and stalled at
// 90% because of Clear-Site-Data poisoning + WebGL context loss. Now we:
//   1. Download the .glb from the backend on first open.
//   2. Cache it in Caches/ (survives reopens, evicted under pressure).
//   3. Parse with GLTFKit2 → SCNScene → SCNView with built-in cameraControl.
//
// Baseline ships the `arthrology` layer (skeleton, ~7MB). Other layers
// (myology, neurology, etc.) come in later commits.

private let atlasLog = Logger(subsystem: "com.bymav.vitaai", category: "Atlas3D")

struct AtlasSceneScreen: View {
    var onBack: () -> Void
    var onAskVita: ((String) -> Void)?

    @State private var scene: SCNScene?
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var loadAttempt = 0

    // Baseline layer — matches `DEFAULT_VISIBLE` in the web viewer.
    private let layer = "arthrology"

    var body: some View {
        // No opaque base — the AppRouter's VitaAmbientBackground shows through.
        VStack(spacing: 0) {
            topBar

            ZStack {
                if let scene {
                    AnatomySceneView(scene: scene)
                        .transition(.opacity)
                } else if let errorMessage {
                    errorView(errorMessage)
                } else {
                    loadingView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarHidden(true)
        .task(id: loadAttempt) { await loadLayer() }
        .trackScreen("Atlas3D")
    }

    // MARK: - Top bar (shell-friendly)

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)

            Text("Atlas 3D")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)

            Spacer()

            Button {
                scene = nil
                errorMessage = nil
                progress = 0
                loadAttempt += 1
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.9))
    }

    // MARK: - Loading & error

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(VitaColors.accent)
                .frame(width: 180)
            Text(progress > 0 ? "Baixando modelo — \(Int(progress * 100))%" : "Carregando Atlas 3D…")
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textSecondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(VitaColors.textSecondary)
            Text("Não foi possível carregar o Atlas")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(VitaColors.textPrimary)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                errorMessage = nil
                loadAttempt += 1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Tentar novamente")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VitaColors.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(VitaColors.accent.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(32)
    }

    // MARK: - Load pipeline

    private func loadLayer() async {
        do {
            let url = try await fetchOrCacheGLB(layer: layer)
            let built = try await buildScene(from: url)
            await MainActor.run {
                self.scene = built
                SentrySDK.reportFullyDisplayed()
            }
        } catch {
            atlasLog.error("[Atlas] load failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    private func fetchOrCacheGLB(layer: String) async throws -> URL {
        let cache = try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let cached = cache.appendingPathComponent("atlas-\(layer).glb")
        if FileManager.default.fileExists(atPath: cached.path) {
            atlasLog.notice("[Atlas] using cached \(layer, privacy: .public).glb")
            return cached
        }

        // anatomy-v2 = Draco-decompressed variant (GLTFKit2 doesn't support
        // KHR_draco_mesh_compression natively). Larger on the wire, cached once.
        guard let remote = URL(string: AppConfig.authBaseURL + "/models/anatomy/anatomy-v2/\(layer).glb") else {
            throw AtlasError.invalidURL
        }
        atlasLog.notice("[Atlas] downloading \(remote.absoluteString, privacy: .public)")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        let session = URLSession(configuration: config)

        let start = Date()
        let (tmpURL, response) = try await session.download(from: remote)
        let elapsed = Date().timeIntervalSince(start)
        atlasLog.notice("[Atlas] download finished in \(elapsed, privacy: .public)s")

        guard let http = response as? HTTPURLResponse else {
            throw AtlasError.httpStatus(-1)
        }
        atlasLog.notice("[Atlas] download response: status=\(http.statusCode) contentLength=\(http.expectedContentLength)")
        guard http.statusCode == 200 else {
            throw AtlasError.httpStatus(http.statusCode)
        }

        try? FileManager.default.removeItem(at: cached)
        try FileManager.default.moveItem(at: tmpURL, to: cached)
        let size = (try? FileManager.default.attributesOfItem(atPath: cached.path)[.size] as? Int) ?? 0
        atlasLog.notice("[Atlas] cached at \(cached.path, privacy: .public) size=\(size)")
        await MainActor.run { self.progress = 1 }
        return cached
    }

    private func buildScene(from url: URL) async throws -> SCNScene {
        atlasLog.notice("[Atlas] buildScene start, url=\(url.path, privacy: .public)")
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        atlasLog.notice("[Atlas] glb file size: \(bytes) bytes")

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SCNScene, Error>) in
            var resumed = false
            GLTFAsset.load(with: url, options: [:]) { _, status, asset, error, _ in
                atlasLog.notice("[Atlas] GLTFAsset.load callback status=\(status.rawValue) hasAsset=\(asset != nil) hasError=\(error != nil)")
                guard !resumed else { return }
                if let error {
                    atlasLog.error("[Atlas] GLTFAsset.load error: \(error.localizedDescription, privacy: .public)")
                    resumed = true
                    continuation.resume(throwing: error)
                    return
                }
                if status == .complete, let asset {
                    resumed = true
                    atlasLog.notice("[Atlas] asset complete: scenes=\(asset.scenes.count) meshes=\(asset.meshes.count) materials=\(asset.materials.count)")

                    let source = GLTFSCNSceneSource(asset: asset)
                    guard let scene = source.defaultScene else {
                        atlasLog.error("[Atlas] GLTFSCNSceneSource.defaultScene is nil")
                        continuation.resume(throwing: AtlasError.noScene)
                        return
                    }
                    atlasLog.notice("[Atlas] scene built: rootChildren=\(scene.rootNode.childNodes.count)")

                    // Ambient + directional so the mesh isn't flat black.
                    let ambient = SCNNode()
                    ambient.light = SCNLight()
                    ambient.light?.type = .ambient
                    ambient.light?.intensity = 550
                    scene.rootNode.addChildNode(ambient)

                    let key = SCNNode()
                    key.light = SCNLight()
                    key.light?.type = .directional
                    key.light?.intensity = 900
                    key.position = SCNVector3(5, 5, 5)
                    key.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
                    scene.rootNode.addChildNode(key)

                    continuation.resume(returning: scene)
                }
            }
        }
    }

    private enum AtlasError: LocalizedError {
        case invalidURL
        case httpStatus(Int)
        case noScene
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "URL do modelo inválida."
            case .httpStatus(let code): return "Servidor respondeu \(code) ao baixar o modelo."
            case .noScene: return "O arquivo .glb não tem cena padrão."
            }
        }
    }
}

// MARK: - Scene view (SwiftUI wrapper)

private struct AnatomySceneView: UIViewRepresentable {
    let scene: SCNScene

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = scene
        view.backgroundColor = .clear
        view.allowsCameraControl = true     // rotate/pan/zoom built-in
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 60
        view.isJitteringEnabled = true

        // Frame the whole scene (union of all geometry), not just first child.
        let (minV, maxV) = scene.rootNode.boundingBox
        let dx = maxV.x - minV.x, dy = maxV.y - minV.y, dz = maxV.z - minV.z
        let diagonal = sqrt(dx * dx + dy * dy + dz * dz)
        atlasLog.notice("[Atlas] scene bbox min=(\(minV.x),\(minV.y),\(minV.z)) max=(\(maxV.x),\(maxV.y),\(maxV.z)) diag=\(diagonal)")

        let camera = SCNCamera()
        camera.zNear = 0.01
        // Fallback distance if bbox is empty (diagonal == 0).
        let safeDiag: Float = diagonal > 0.0001 ? diagonal : 2.0
        camera.zFar = Double(safeDiag) * 20
        let camNode = SCNNode()
        camNode.camera = camera
        let cx = (minV.x + maxV.x) / 2
        let cy = (minV.y + maxV.y) / 2
        let cz = (minV.z + maxV.z) / 2
        camNode.position = SCNVector3(cx, cy, cz + safeDiag * 1.6)
        camNode.look(at: SCNVector3(cx, cy, cz))
        scene.rootNode.addChildNode(camNode)
        view.pointOfView = camNode

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
