import Foundation
import Network
import SwiftUI

/// Manages the WebSocket connection to a Pi5 daemon.
/// Single source of truth for connection state across all platforms.
@MainActor
final class PiSession: ObservableObject {
    enum State: Equatable {
        case idle
        case connecting
        case connected
        case error(String)
    }

    @Published var state: State = .idle
    @Published var host: String = ""
    @Published var port: Int = 8765
    @Published var rttMs: Int? = nil

    private var task: URLSessionWebSocketTask?
    private var session: URLSession = .shared
    private var pingTimer: Timer?

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    // MARK: - Connect

    func connect(host: String, port: Int = 8765) {
        disconnect()
        // Strip trailing dots (Bonjour hosts often come back as "raspberrypi.local.")
        // and any whitespace the user may have pasted in.
        let cleanHost = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .split(separator: "%").first.map(String.init) ?? ""
        guard !cleanHost.isEmpty else {
            self.state = .error("enter a host or IP")
            return
        }
        self.host = cleanHost
        self.port = port
        self.state = .connecting

        var components = URLComponents()
        components.scheme = "ws"
        components.host = cleanHost
        components.port = port
        components.path = "/ws"
        guard let url = components.url else {
            self.state = .error("bad url: \(cleanHost):\(port)")
            return
        }

        let req = URLRequest(url: url)
        let t = session.webSocketTask(with: req)
        self.task = t
        t.resume()

        send(.hello(client: deviceName(), version: "0.1.0"))
        listen()
        startPing()
        self.state = .connected
    }

    func connect(endpoint: NWEndpoint) {
        self.state = .connecting
        // If the endpoint is already a hostPort we can short-circuit.
        if case let .hostPort(h, p) = endpoint {
            connect(host: hostStringFor(h), port: Int(p.rawValue))
            return
        }
        // Otherwise (Bonjour service), open a probe NWConnection to resolve the
        // service to a real host:port, then hand off to the WebSocket connect.
        let conn = NWConnection(to: endpoint, using: .tcp)
        conn.stateUpdateHandler = { [weak self] s in
            switch s {
            case .ready:
                if let remote = conn.currentPath?.remoteEndpoint,
                   case let .hostPort(h, p) = remote {
                    let hostStr = self?.hostStringFor(h) ?? ""
                    let port = Int(p.rawValue)
                    Task { @MainActor in
                        self?.connect(host: hostStr, port: port)
                    }
                }
                conn.cancel()
            case .failed(let err):
                Task { @MainActor in self?.state = .error(err.localizedDescription) }
                conn.cancel()
            default: break
            }
        }
        conn.start(queue: .main)
    }

    nonisolated private func hostStringFor(_ h: NWEndpoint.Host) -> String {
        let raw: String
        switch h {
        case .ipv4(let ip): raw = "\(ip)"
        case .ipv6(let ip): raw = "[\(ip)]"
        case .name(let n, _): raw = n
        @unknown default: raw = "\(h)"
        }
        // Strip zone identifiers like "%en0" that iOS appends when resolving
        // link-local Bonjour endpoints — they break URLComponents.
        return raw.split(separator: "%").first.map(String.init) ?? raw
    }

    /// Reset the error state so the UI doesn't keep showing a stale message.
    func clearError() {
        if case .error = state { state = .idle }
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .idle
    }

    // MARK: - Send

    func send(_ msg: WireMessage) {
        guard let task else { return }
        do {
            let data = try JSONEncoder().encode(msg)
            let str = String(data: data, encoding: .utf8) ?? ""
            task.send(.string(str)) { [weak self] err in
                if let err {
                    Task { @MainActor in self?.state = .error(err.localizedDescription) }
                }
            }
        } catch {
            self.state = .error(error.localizedDescription)
        }
    }

    func tap(_ code: String, modifiers: [String] = []) {
        send(.key(KeyEvent(code: code, down: true,  modifiers: modifiers)))
        send(.key(KeyEvent(code: code, down: false, modifiers: modifiers)))
    }

    func type(_ s: String) {
        send(.text(s))
    }

    // MARK: - Receive

    private func listen() {
        task?.receive { [weak self] result in
            switch result {
            case .failure(let err):
                Task { @MainActor in self?.state = .error(err.localizedDescription) }
            case .success(let msg):
                Task { @MainActor in self?.handle(msg) }
                self?.listen()
            }
        }
    }

    private func handle(_ msg: URLSessionWebSocketTask.Message) {
        switch msg {
        case .string(let s):
            if let data = s.data(using: .utf8),
               let wire = try? JSONDecoder().decode(WireMessage.self, from: data),
               case .pong = wire {
                // pong handled by ping timer
            }
        case .data: break
        @unknown default: break
        }
    }

    // MARK: - Keepalive

    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.send(.ping) }
        }
    }

    private func deviceName() -> String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(watchOS)
        return "watchOS"
        #else
        return "unknown"
        #endif
    }
}
