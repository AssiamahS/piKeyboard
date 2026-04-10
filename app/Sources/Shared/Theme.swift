import SwiftUI

enum Theme {
    static let bg          = Color(red: 0.05, green: 0.06, blue: 0.09)   // near-black
    static let surface     = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let surfaceHi   = Color(red: 0.14, green: 0.16, blue: 0.22)
    static let stroke      = Color.white.opacity(0.06)
    static let textPrimary = Color.white
    static let textMuted   = Color.white.opacity(0.55)
    static let accent      = Color(red: 0.22, green: 0.74, blue: 0.97)   // sky blue
    static let accentSoft  = Color(red: 0.22, green: 0.74, blue: 0.97).opacity(0.18)
    static let success     = Color(red: 0.29, green: 0.87, blue: 0.5)
    static let danger      = Color(red: 0.97, green: 0.45, blue: 0.45)

    static let radius: CGFloat       = 14
    static let radiusKey: CGFloat    = 10
    static let spacing: CGFloat      = 10
}

struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}
