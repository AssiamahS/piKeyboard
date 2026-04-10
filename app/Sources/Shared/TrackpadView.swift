import SwiftUI

#if !os(watchOS)
struct TrackpadView: View {
    @EnvironmentObject var session: PiSession
    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        VStack(spacing: 12) {
            surface
            buttons
        }
        .padding(16)
    }

    private var surface: some View {
        RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
            .fill(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .overlay(
                Text("Slide to move")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let dx = v.translation.width  - lastTranslation.width
                        let dy = v.translation.height - lastTranslation.height
                        lastTranslation = v.translation
                        if dx != 0 || dy != 0 {
                            session.send(.mouse(MouseEvent(dx: Double(dx), dy: Double(dy), button: nil, down: nil)))
                        }
                    }
                    .onEnded { _ in
                        lastTranslation = .zero
                    }
            )
            .onTapGesture {
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: true)))
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: false)))
            }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            mouseButton(title: "Left", button: "left")
            mouseButton(title: "Middle", button: "middle")
            mouseButton(title: "Right", button: "right")
        }
        .frame(height: 56)
    }

    private func mouseButton(title: String, button: String) -> some View {
        Button {
            session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: button, down: true)))
            session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: button, down: false)))
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.surface)
                .foregroundStyle(Theme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusKey, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusKey, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
#endif
