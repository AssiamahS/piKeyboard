import Foundation

/// Wire protocol shared by client + Pi5 daemon.
/// JSON messages over WebSocket. Keep it minimal.
enum WireMessage: Codable {
    case hello(client: String, version: String)
    case key(KeyEvent)
    case mouse(MouseEvent)
    case scroll(dx: Double, dy: Double)
    case text(String)
    case ping
    case pong

    enum CodingKeys: String, CodingKey { case t, p }

    private enum Tag: String, Codable {
        case hello, key, mouse, scroll, text, ping, pong
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let client, let version):
            try c.encode(Tag.hello, forKey: .t)
            try c.encode(["client": client, "version": version], forKey: .p)
        case .key(let e):
            try c.encode(Tag.key, forKey: .t)
            try c.encode(e, forKey: .p)
        case .mouse(let e):
            try c.encode(Tag.mouse, forKey: .t)
            try c.encode(e, forKey: .p)
        case .scroll(let dx, let dy):
            try c.encode(Tag.scroll, forKey: .t)
            try c.encode(["dx": dx, "dy": dy], forKey: .p)
        case .text(let s):
            try c.encode(Tag.text, forKey: .t)
            try c.encode(["s": s], forKey: .p)
        case .ping:
            try c.encode(Tag.ping, forKey: .t)
        case .pong:
            try c.encode(Tag.pong, forKey: .t)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let tag = try c.decode(Tag.self, forKey: .t)
        switch tag {
        case .hello:
            let p = try c.decode([String: String].self, forKey: .p)
            self = .hello(client: p["client"] ?? "", version: p["version"] ?? "")
        case .key:
            self = .key(try c.decode(KeyEvent.self, forKey: .p))
        case .mouse:
            self = .mouse(try c.decode(MouseEvent.self, forKey: .p))
        case .scroll:
            let p = try c.decode([String: Double].self, forKey: .p)
            self = .scroll(dx: p["dx"] ?? 0, dy: p["dy"] ?? 0)
        case .text:
            let p = try c.decode([String: String].self, forKey: .p)
            self = .text(p["s"] ?? "")
        case .ping: self = .ping
        case .pong: self = .pong
        }
    }
}

struct KeyEvent: Codable {
    var code: String          // e.g. "KEY_A", "KEY_ENTER", "KEY_LEFTSHIFT"
    var down: Bool
    var modifiers: [String]   // ["shift","ctrl","alt","meta"]
}

struct MouseEvent: Codable {
    var dx: Double
    var dy: Double
    var button: String?       // "left" | "right" | "middle" | nil
    var down: Bool?
}
