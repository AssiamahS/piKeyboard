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
                VStack(spacing: 4) {
                    Text("Slide to move")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                    Text("Tap to click")
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted.opacity(0.7))
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // SimultaneousGesture lets tap and drag both register without one
            // swallowing the other. minimumDistance: 5 on the drag means a quick
            // tap (no movement) only fires the TapGesture.
            .gesture(
                SimultaneousGesture(
                    TapGesture(count: 1).onEnded {
                        session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: true)))
                        session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: false)))
                    },
                    DragGesture(minimumDistance: 5)
                        .onChanged { v in
                            let dx = v.translation.width  - lastTranslation.width
                            let dy = v.translation.height - lastTranslation.height
                            lastTranslation = v.translation
                            if dx != 0 || dy != 0 {
                                session.send(.mouse(MouseEvent(
                                    dx: Double(dx), dy: Double(dy),
                                    button: nil, down: nil)))
                            }
                        }
                        .onEnded { _ in
                            lastTranslation = .zero
                        }
                )
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    // Double-tap = double left-click
                    for _ in 0..<2 {
                        session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: true)))
                        session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: false)))
                    }
                }
            )
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
