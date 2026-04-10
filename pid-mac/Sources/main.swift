import Foundation
import Network
import CoreGraphics
import AppKit

// piKeyboard Mac listener.
// WebSocket-ish protocol over plain TCP for simplicity (same JSON message shape
// as the Pi daemon and the Apple client). Advertises via Bonjour.
//
// Build:  swift build -c release
// Run:    .build/release/pikeyboardd
//
// Requires: System Settings → Privacy & Security → Accessibility → enable for Terminal/iTerm
// (only needed because CGEvent.post requires it for non-self processes).

let PORT: UInt16 = 8765
let SERVICE_TYPE = "_pikeyboard._tcp"

// MARK: - Protocol

struct Wire: Decodable {
    let t: String
    let p: AnyJSON?
}

enum AnyJSON: Decodable {
    case dict([String: AnyJSON]), array([AnyJSON]), string(String), number(Double), bool(Bool), null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([AnyJSON].self) { self = .array(v); return }
        if let v = try? c.decode([String: AnyJSON].self) { self = .dict(v); return }
        self = .null
    }

    var asString: String? { if case .string(let s) = self { return s } else { return nil } }
    var asDouble: Double? { if case .number(let n) = self { return n } else { return nil } }
    var asBool: Bool?     { if case .bool(let b) = self { return b } else { return nil } }
    var asArray: [AnyJSON]? { if case .array(let a) = self { return a } else { return nil } }
    subscript(_ key: String) -> AnyJSON? {
        if case .dict(let d) = self { return d[key] } else { return nil }
    }
}

// MARK: - Injector

enum Injector {
    static func key(code: String, down: Bool, modifiers: [String]) {
        guard let cg = keycode(for: code) else { return }
        let src = CGEventSource(stateID: .hidSystemState)
        let ev = CGEvent(keyboardEventSource: src, virtualKey: cg, keyDown: down)
        var flags: CGEventFlags = []
        if modifiers.contains("shift") { flags.insert(.maskShift) }
        if modifiers.contains("ctrl")  { flags.insert(.maskControl) }
        if modifiers.contains("alt")   { flags.insert(.maskAlternate) }
        if modifiers.contains("meta")  { flags.insert(.maskCommand) }
        ev?.flags = flags
        ev?.post(tap: .cghidEventTap)
    }

    static func text(_ s: String) {
        // Use unicode keyboard event to type arbitrary chars without keymap juggling.
        let src = CGEventSource(stateID: .hidSystemState)
        for ch in s {
            let str = String(ch)
            let utf16 = Array(str.utf16)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            utf16.withUnsafeBufferPointer { buf in
                if let base = buf.baseAddress {
                    down?.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: base)
                    up?.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: base)
                }
            }
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    static func mouseMove(dx: Double, dy: Double) {
        let cur = CGEvent(source: nil)?.location ?? .zero
        let new = CGPoint(x: cur.x + dx, y: cur.y + dy)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                mouseCursorPosition: new, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    static func mouseButton(_ button: String, down: Bool) {
        let cur = CGEvent(source: nil)?.location ?? .zero
        let (type, btn): (CGEventType, CGMouseButton) = {
            switch (button, down) {
            case ("left",   true):  return (.leftMouseDown,   .left)
            case ("left",   false): return (.leftMouseUp,     .left)
            case ("right",  true):  return (.rightMouseDown,  .right)
            case ("right",  false): return (.rightMouseUp,    .right)
            case ("middle", true):  return (.otherMouseDown,  .center)
            case ("middle", false): return (.otherMouseUp,    .center)
            default:                return (.leftMouseDown,   .left)
            }
        }()
        CGEvent(mouseEventSource: nil, mouseType: type,
                mouseCursorPosition: cur, mouseButton: btn)?
            .post(tap: .cghidEventTap)
    }

    static func scroll(dx: Double, dy: Double) {
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0)?
            .post(tap: .cghidEventTap)
    }

    /// Map a "KEY_X" string from the wire protocol to a CGKeyCode.
    static func keycode(for code: String) -> CGKeyCode? {
        // Subset — full ANSI layout. Add as needed.
        let m: [String: CGKeyCode] = [
            "KEY_A":0,"KEY_S":1,"KEY_D":2,"KEY_F":3,"KEY_H":4,"KEY_G":5,"KEY_Z":6,"KEY_X":7,
            "KEY_C":8,"KEY_V":9,"KEY_B":11,"KEY_Q":12,"KEY_W":13,"KEY_E":14,"KEY_R":15,
            "KEY_Y":16,"KEY_T":17,"KEY_1":18,"KEY_2":19,"KEY_3":20,"KEY_4":21,"KEY_6":22,
            "KEY_5":23,"KEY_EQUAL":24,"KEY_9":25,"KEY_7":26,"KEY_MINUS":27,"KEY_8":28,
            "KEY_0":29,"KEY_RIGHTBRACE":30,"KEY_O":31,"KEY_U":32,"KEY_LEFTBRACE":33,
            "KEY_I":34,"KEY_P":35,"KEY_ENTER":36,"KEY_L":37,"KEY_J":38,"KEY_APOSTROPHE":39,
            "KEY_K":40,"KEY_SEMICOLON":41,"KEY_BACKSLASH":42,"KEY_COMMA":43,"KEY_SLASH":44,
            "KEY_N":45,"KEY_M":46,"KEY_DOT":47,"KEY_TAB":48,"KEY_SPACE":49,"KEY_GRAVE":50,
            "KEY_BACKSPACE":51,"KEY_ESC":53,
            "KEY_LEFT":123,"KEY_RIGHT":124,"KEY_DOWN":125,"KEY_UP":126,
        ]
        return m[code]
    }
}

// MARK: - Server

final class Server {
    private var listener: NWListener?

    func start() throws {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: PORT)!)
        l.service = NWListener.Service(name: Host.current().localizedName ?? "Mac",
                                       type: SERVICE_TYPE)
        l.newConnectionHandler = { [weak self] conn in
            self?.accept(conn)
        }
        l.stateUpdateHandler = { state in
            print("[server] state=\(state)")
        }
        l.start(queue: .main)
        self.listener = l
        print("[server] listening on tcp/\(PORT), Bonjour=\(SERVICE_TYPE)")
    }

    private func accept(_ conn: NWConnection) {
        print("[server] client connected")
        conn.start(queue: .main)
        receive(conn)
    }

    private func receive(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, done, err in
            if let data, !data.isEmpty {
                self?.handle(data)
            }
            if done || err != nil {
                print("[server] client gone")
                conn.cancel()
                return
            }
            self?.receive(conn)
        }
    }

    private func handle(_ data: Data) {
        // Newline-delimited JSON for simplicity
        let lines = data.split(separator: 0x0A)
        for line in lines {
            guard let wire = try? JSONDecoder().decode(Wire.self, from: Data(line)) else { continue }
            apply(wire)
        }
    }

    private func apply(_ w: Wire) {
        switch w.t {
        case "key":
            let code = w.p?["code"]?.asString ?? ""
            let down = w.p?["down"]?.asBool ?? false
            let mods = w.p?["modifiers"]?.asArray?.compactMap { $0.asString } ?? []
            Injector.key(code: code, down: down, modifiers: mods)
        case "text":
            Injector.text(w.p?["s"]?.asString ?? "")
        case "mouse":
            let dx = w.p?["dx"]?.asDouble ?? 0
            let dy = w.p?["dy"]?.asDouble ?? 0
            if let b = w.p?["button"]?.asString {
                Injector.mouseButton(b, down: w.p?["down"]?.asBool ?? false)
            } else {
                Injector.mouseMove(dx: dx, dy: dy)
            }
        case "scroll":
            Injector.scroll(dx: w.p?["dx"]?.asDouble ?? 0, dy: w.p?["dy"]?.asDouble ?? 0)
        case "hello":
            print("[server] hello \(w.p?["client"]?.asString ?? "?") v\(w.p?["version"]?.asString ?? "?")")
        default: break
        }
    }
}

// MARK: - Entry

let server = Server()
do {
    try server.start()
} catch {
    print("failed to start: \(error)")
    exit(2)
}

RunLoop.main.run()
