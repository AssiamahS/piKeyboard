import SwiftUI

#if !os(watchOS)
struct TrackpadView: View {
    @EnvironmentObject var session: PiSession
    @State private var lastTranslation: CGSize = .zero
    @State private var hasMoved: Bool = false
    @State private var touchStart: Date = .distantPast

    /// Distance (in points) past which a touch becomes a drag instead of a tap.
    private let tapSlop: CGFloat = 6

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
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !hasMoved {
                            touchStart = touchStart == .distantPast ? Date() : touchStart
                            let dist = hypot(v.translation.width, v.translation.height)
                            if dist > tapSlop {
                                hasMoved = true
                                lastTranslation = v.translation
                            }
                            return
                        }
                        let dx = v.translation.width  - lastTranslation.width
                        let dy = v.translation.height - lastTranslation.height
                        lastTranslation = v.translation
                        if dx != 0 || dy != 0 {
                            session.send(.mouse(MouseEvent(dx: Double(dx), dy: Double(dy), button: nil, down: nil)))
                        }
                    }
                    .onEnded { _ in
                        // No movement past slop = it was a tap → fire a left click.
                        if !hasMoved {
                            session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: true)))
                            session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: false)))
                        }
                        hasMoved = false
                        lastTranslation = .zero
                        touchStart = .distantPast
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
