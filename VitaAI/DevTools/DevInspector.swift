#if DEBUG
import SwiftUI
import OSLog

// MARK: - DevInspector — "aponta e fala" (pedido Rafael 2026-07-24)
//
// Igual à ferramenta do One: entro no modo de seleção (botão flutuante 🎯 OU
// hotkey Ctrl+Shift+A no Mac → deep link vitaai://devinspect), toco no componente
// no simulador, vejo o NOME dele (quando marcado com `.devTag`) + as coordenadas,
// escrevo o que quero mudar e mando pro agente. O agente lê o pedido em:
//   <container-do-app>/Documents/dev-inspect.jsonl
// (leio via `xcrun simctl get_app_container booted com.bymav.vitaai data`).
//
// Só existe em DEBUG e é plugado na RAIZ do app → aparece em TODA build de
// simulador automaticamente, sem setup por-sim.

// MARK: Registro de componentes marcados

final class DevInspectorRegistry: ObservableObject {
    static let shared = DevInspectorRegistry()
    struct Tagged { let name: String; let source: String; let frame: CGRect }
    private var tagged: [String: Tagged] = [:]

    func report(id: String, name: String, source: String, frame: CGRect) {
        tagged[id] = Tagged(name: name, source: source, frame: frame)
    }
    func clear(id: String) { tagged[id] = nil }

    /// Menor frame marcado que contém o ponto (o componente mais específico).
    func hit(_ p: CGPoint) -> Tagged? {
        tagged.values
            .filter { $0.frame.contains(p) }
            .min { ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height) }
    }
}

extension View {
    /// Marca um componente pro inspetor. `name` é o que aparece na ferramenta;
    /// o arquivo:linha onde a tag foi posta vai junto (pro agente saber a fonte).
    func devTag(_ name: String, file: String = #fileID, line: Int = #line) -> some View {
        modifier(DevTagModifier(name: name, source: "\(file):\(line)"))
    }
}

private struct DevTagModifier: ViewModifier {
    let name: String
    let source: String
    @State private var id = UUID().uuidString

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { DevInspectorRegistry.shared.report(id: id, name: name, source: source, frame: geo.frame(in: .global)) }
                    .onChange(of: geo.frame(in: .global)) { f in
                        DevInspectorRegistry.shared.report(id: id, name: name, source: source, frame: f)
                    }
                    .onDisappear { DevInspectorRegistry.shared.clear(id: id) }
            }
        )
    }
}

extension Notification.Name {
    static let devInspectorToggle = Notification.Name("devInspectorToggle")
}

// MARK: Host (botão + modo pick + card de nota)

struct DevInspectorHost: View {
    @State private var picking = false
    @State private var tap: CGPoint?
    @State private var hover: CGPoint?          // dedo arrastando (pré-seleção)
    @State private var hoverFrame: CGRect?      // realce do componente sob o dedo
    @State private var hoverName: String?
    @State private var hitName: String?
    @State private var hitSource: String?
    @State private var note = ""
    @State private var enviado = false
    @State private var kbHeight: CGFloat = 0
    @FocusState private var noteFocused: Bool
    // posição do botão (arrastável), guardada entre execuções. -1 = ainda no default.
    @AppStorage("devInspectorBtnX") private var btnX: Double = -1
    @AppStorage("devInspectorBtnY") private var btnY: Double = -1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if picking {
                    pickLayer
                    if tap == nil { hoverRealce; dicaTopo }
                }
                if let tap {
                    marcador(at: tap)
                    cardNota
                }
                botaoFlutuante(geo)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: picking)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tap)
        .onReceive(NotificationCenter.default.publisher(for: .devInspectorToggle)) { _ in toggle() }
        .onOpenURL { url in if url.host == "devinspect" { toggle() } }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            if let f = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect { kbHeight = f.height }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in kbHeight = 0 }
    }

    // MARK: modo pick (arrasta o dedo = pré-seleciona; solta = seleciona)

    private var pickLayer: some View {
        Color.black.opacity(tap == nil ? 0.14 : 0.32)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { v in
                        hover = v.location
                        let h = DevInspectorRegistry.shared.hit(v.location)
                        hoverFrame = h?.frame
                        hoverName = h?.name
                    }
                    .onEnded { v in capturar(v.location) }
            )
    }

    /// Realce do componente sob o dedo + etiqueta com o nome (igual o hover do Windows).
    @ViewBuilder private var hoverRealce: some View {
        if let f = hoverFrame {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.cyan, lineWidth: 2)
                .background(RoundedRectangle(cornerRadius: 8).fill(.cyan.opacity(0.18)))
                .frame(width: f.width, height: f.height)
                .position(x: f.midX, y: f.midY)
                .allowsHitTesting(false)
        }
        if let hover, let hoverName {
            Text(hoverName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(.cyan.opacity(0.95)))
                .position(x: hover.x, y: max(28, hover.y - 34))
                .allowsHitTesting(false)
        }
    }

    // MARK: peças

    private func botaoFlutuante(_ geo: GeometryProxy) -> some View {
        let px = btnX < 0 ? geo.size.width - 30 : btnX
        let py = btnY < 0 ? 70.0 : btnY
        return Image(systemName: picking ? "xmark" : "scope")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(picking ? Color.red.opacity(0.92) : Color.blue.opacity(0.9)))
            .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 5, y: 2)
            .position(x: px, y: py)
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { v in btnX = v.location.x; btnY = v.location.y }
            )
            .onTapGesture { toggle() }
            .accessibilityIdentifier("dev_inspector_toggle")
    }

    private var dicaTopo: some View {
        VStack {
            Text("Arraste o dedo pra realçar · solte pra selecionar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(.blue.opacity(0.9)))
                .padding(.top, 58)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    private func marcador(at p: CGPoint) -> some View {
        ZStack {
            Circle().strokeBorder(.yellow, lineWidth: 2).frame(width: 34, height: 34)
            Circle().fill(.yellow).frame(width: 6, height: 6)
        }
        .position(p)
        .allowsHitTesting(false)
    }

    private var cardNota: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "scope").font(.system(size: 12, weight: .bold))
                    Text(hitName ?? "Componente (sem tag)")
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    Spacer()
                    if let tap {
                        Text("(\(Int(tap.x)), \(Int(tap.y)))")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                if let hitSource {
                    Text(hitSource)
                        .font(.system(size: 11).monospaced())
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }

                TextField("O que você quer que eu faça com isto?", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.blue.opacity(0.7), lineWidth: 1))
                    .focused($noteFocused)

                HStack(spacing: 10) {
                    Button("Cancelar") { resetCard() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Button {
                        enviar()
                    } label: {
                        Text(enviado ? "Enviado ✓" : "Enviar pro agente")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(Capsule().fill(enviado ? .green : .blue))
                    }
                    .buttonStyle(.plain)
                    .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(red: 0.10, green: 0.11, blue: 0.14)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
            .padding(.horizontal, 12)
            .padding(.bottom, kbHeight > 0 ? kbHeight + 10 : 34)   // acima do teclado
        }
        .animation(.easeOut(duration: 0.25), value: kbHeight)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: lógica

    private func toggle() {
        picking.toggle()
        if !picking { resetCard() }
    }

    private func capturar(_ p: CGPoint) {
        tap = p
        let h = DevInspectorRegistry.shared.hit(p)
        hitName = h?.name
        hitSource = h?.source
        hover = nil; hoverFrame = nil; hoverName = nil
        enviado = false
        noteFocused = true
    }

    private func resetCard() {
        tap = nil; hitName = nil; hitSource = nil; note = ""; enviado = false; noteFocused = false
        hover = nil; hoverFrame = nil; hoverName = nil
    }

    private func enviar() {
        let rec: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "x": Int(tap?.x ?? 0),
            "y": Int(tap?.y ?? 0),
            "component": hitName ?? "",
            "source": hitSource ?? "",
            "note": note.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: rec),
            var line = String(data: data, encoding: .utf8)
        else { return }
        line += "\n"

        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dev-inspect.jsonl")
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
        } else {
            try? line.data(using: .utf8)!.write(to: url)
        }
        Logger(subsystem: "com.bymav.vitaai", category: "devinspect")
            .notice("[devinspect] \(line.trimmingCharacters(in: .newlines), privacy: .public)")

        enviado = true
        // some o card depois de um instante, mantendo o modo pick pra marcar outro
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            resetCard()
        }
    }
}
#endif

#if !DEBUG
import SwiftUI
extension View {
    /// No-op em release — o DevInspector (e o `.devTag`) só existem em DEBUG.
    @inline(__always) func devTag(_ name: String, file: String = #fileID, line: Int = #line) -> some View { self }
}
#endif
