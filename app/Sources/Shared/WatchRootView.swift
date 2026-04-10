import SwiftUI

#if os(watchOS)
struct WatchRootView: View {
    @EnvironmentObject var session: PiSession
    @State private var host: String = ""

    var body: some View {
        NavigationStack {
            if session.isConnected {
                WatchControlView()
            } else {
                Form {
                    Section("Pi") {
                        TextField("IP", text: $host)
                        Button("Connect") {
                            guard !host.isEmpty else { return }
                            session.connect(host: host)
                        }
                    }
                }
                .navigationTitle("piKeyboard")
            }
        }
    }
}

struct WatchControlView: View {
    @EnvironmentObject var session: PiSession

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Button("⏎ Enter")  { session.tap("KEY_ENTER") }
                Button("⌫ Back")   { session.tap("KEY_BACKSPACE") }
                Button("esc")      { session.tap("KEY_ESC") }
                Button("⌃C")       { session.tap("KEY_C", modifiers: ["ctrl"]) }
                Button("clear")    { session.tap("KEY_L", modifiers: ["ctrl"]) }
                Button("Disconnect", role: .destructive) { session.disconnect() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .navigationTitle("Connected")
    }
}
#endif
