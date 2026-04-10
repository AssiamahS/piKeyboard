import SwiftUI

@main
struct PiKeyboardApp: App {
    @StateObject private var session = PiSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
