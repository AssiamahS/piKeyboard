import SwiftUI
#if os(iOS)
import UIKit
#endif

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
            #if os(iOS)
            // Two-finger pan = scroll. UIPanGestureRecognizer with min/max touches=2
            // doesn't fire for 1-finger gestures, so it lives alongside the
            // SwiftUI tap+drag without conflict.
            .overlay(
                TwoFingerScrollOverlay { dx, dy in
                    // Map iOS drag direction to natural scroll. Dragging fingers
                    // DOWN should scroll page DOWN, which on the wire means
                    // negative wheel delta (REL_WHEEL positive = wheel up).
                    let scale = 0.18
                    session.send(.scroll(dx: Double(dx) * scale,
                                         dy: -Double(dy) * scale))
                }
                .allowsHitTesting(true)
            )
            #endif
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            mouseButton(title: "Left", button: "left")
            mouseButton(title: "Middle", button: "middle")
            mouseButton(title: "Right", button: "right")
        }
        .frame(height: 56)
    }

    #if os(iOS)
    /// UIKit wrapper that listens for **two-finger pans** and emits scroll
    /// deltas. Has to be UIKit because SwiftUI doesn't expose finger count
    /// on its DragGesture. Configured to coexist with the SwiftUI 1-finger
    /// gestures via `cancelsTouchesInView = false` and a permissive delegate.
    fileprivate struct TwoFingerScrollOverlay: UIViewRepresentable {
        let onScroll: (CGFloat, CGFloat) -> Void

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = true
            let pan = UIPanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handle(_:))
            )
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            pan.cancelsTouchesInView = false
            pan.delaysTouchesBegan = false
            pan.delegate = context.coordinator
            view.addGestureRecognizer(pan)
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {}

        func makeCoordinator() -> Coordinator { Coordinator(onScroll: onScroll) }

        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            let onScroll: (CGFloat, CGFloat) -> Void
            private var last: CGPoint = .zero

            init(onScroll: @escaping (CGFloat, CGFloat) -> Void) {
                self.onScroll = onScroll
            }

            @objc func handle(_ pan: UIPanGestureRecognizer) {
                switch pan.state {
                case .began:
                    last = .zero
                case .changed:
                    let t = pan.translation(in: pan.view)
                    let dx = t.x - last.x
                    let dy = t.y - last.y
                    last = t
                    if dx != 0 || dy != 0 {
                        onScroll(dx, dy)
                    }
                case .ended, .cancelled, .failed:
                    last = .zero
                default: break
                }
            }

            // Let our 2-finger pan run alongside SwiftUI's 1-finger drag/tap.
            func gestureRecognizer(
                _ g: UIGestureRecognizer,
                shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
            ) -> Bool { true }
        }
    }
    #endif

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
