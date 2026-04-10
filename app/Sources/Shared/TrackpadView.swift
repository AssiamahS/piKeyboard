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
        #if os(iOS)
        TrackpadSurfaceView(
            onMove: { dx, dy in
                session.send(.mouse(MouseEvent(
                    dx: Double(dx), dy: Double(dy),
                    button: nil, down: nil)))
            },
            onScroll: { dx, dy in
                // Natural scroll: dragging two fingers DOWN scrolls page DOWN.
                // X11 wheel: positive = up, so negate dy. Scale 0.12 makes a
                // comfortable swipe = a few wheel ticks instead of jumping.
                let scale = 0.12
                session.send(.scroll(
                    dx: Double(dx) * scale,
                    dy: -Double(dy) * scale))
            },
            onTap: {
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: true)))
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: false)))
            },
            onLongPress: {
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "right", down: true)))
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "right", down: false)))
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        // macOS fallback: SwiftUI gestures only.
        RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
            .fill(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
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
                    .onEnded { _ in lastTranslation = .zero }
            )
        #endif
    }

    /// Palm Pilot–style bottom row: two wide flank buttons with a centered
    /// orb in the middle. Click events are real (left/middle/right), the
    /// little inner dot on the orb is purely decorative — there for the look.
    private var buttons: some View {
        HStack(spacing: 14) {
            palmFlank(side: .left) {
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: true)))
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: false)))
            }
            palmOrb {
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "middle", down: true)))
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "middle", down: false)))
            }
            palmFlank(side: .right) {
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "right", down: true)))
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "right", down: false)))
            }
        }
        .frame(height: 64)
    }

    private enum FlankSide { case left, right }

    private func palmFlank(side: FlankSide, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.16),
                            Color(white: 0.08),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.10),
                                    Color.black.opacity(0.35),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    Image(systemName: side == .left ? "chevron.compact.left" : "chevron.compact.right")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The Palm Pilot center scroll-ball. Functional middle-click + a tiny
    /// decorative LED-style dot offset to the upper-left for visual flair.
    private func palmOrb(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(white: 0.22),
                                Color(white: 0.06),
                            ],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 2,
                            endRadius: 38
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.22),
                                        Color.black.opacity(0.45),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )
                // Tiny inner ring — pure decoration, evokes a hardware sensor
                Circle()
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                    .frame(width: 22, height: 22)
                // The "LED" — never lights up, just a static spec for character
                Circle()
                    .fill(Theme.accent.opacity(0.55))
                    .frame(width: 3.5, height: 3.5)
                    .offset(x: -10, y: -10)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 64, height: 64)
    }

    #if os(iOS)
    /// Single UIKit view that owns ALL trackpad gestures. Pro trackpad apps
    /// (Mobile Mouse, Air Mouse) all do this — SwiftUI's gesture system can't
    /// reliably mix 1-finger and 2-finger pans without one swallowing the other.
    /// UIKit's gesture recognizer subsystem disambiguates them properly.
    ///
    /// Gestures attached:
    ///   - 1-finger pan      → cursor move (REL_X / REL_Y)
    ///   - 2-finger pan      → scroll (REL_WHEEL)
    ///   - Tap (1 touch)     → left click
    ///   - Long press (0.4s) → right click
    fileprivate struct TrackpadSurfaceView: UIViewRepresentable {
        let onMove:      (CGFloat, CGFloat) -> Void
        let onScroll:    (CGFloat, CGFloat) -> Void
        let onTap:       () -> Void
        let onLongPress: () -> Void

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
            view.layer.cornerRadius = 14
            view.layer.borderWidth = 1
            view.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
            view.isUserInteractionEnabled = true

            let coord = context.coordinator

            // 1-finger pan → cursor move
            let movePan = UIPanGestureRecognizer(
                target: coord,
                action: #selector(Coordinator.handleMove(_:))
            )
            movePan.minimumNumberOfTouches = 1
            movePan.maximumNumberOfTouches = 1
            movePan.delegate = coord
            view.addGestureRecognizer(movePan)

            // 2-finger pan → scroll
            let scrollPan = UIPanGestureRecognizer(
                target: coord,
                action: #selector(Coordinator.handleScroll(_:))
            )
            scrollPan.minimumNumberOfTouches = 2
            scrollPan.maximumNumberOfTouches = 2
            scrollPan.delegate = coord
            view.addGestureRecognizer(scrollPan)

            // Single tap (1 finger) → left click
            let tap = UITapGestureRecognizer(
                target: coord, action: #selector(Coordinator.handleTap)
            )
            tap.numberOfTapsRequired = 1
            tap.numberOfTouchesRequired = 1
            tap.delegate = coord
            view.addGestureRecognizer(tap)

            // 2-finger tap → right click (Mac trackpad convention)
            let twoFingerTap = UITapGestureRecognizer(
                target: coord, action: #selector(Coordinator.handleRightClick)
            )
            twoFingerTap.numberOfTapsRequired = 1
            twoFingerTap.numberOfTouchesRequired = 2
            twoFingerTap.delegate = coord
            view.addGestureRecognizer(twoFingerTap)

            // Long press (1 finger held 0.4s) → right click (iOS convention)
            let longPress = UILongPressGestureRecognizer(
                target: coord, action: #selector(Coordinator.handleLongPress(_:))
            )
            longPress.minimumPressDuration = 0.4
            longPress.allowableMovement = 8
            longPress.delegate = coord
            view.addGestureRecognizer(longPress)

            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(onMove: onMove, onScroll: onScroll,
                        onTap: onTap, onLongPress: onLongPress)
        }

        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            let onMove:      (CGFloat, CGFloat) -> Void
            let onScroll:    (CGFloat, CGFloat) -> Void
            let onTap:       () -> Void
            let onLongPress: () -> Void

            private var moveLast:   CGPoint = .zero
            private var scrollLast: CGPoint = .zero

            init(onMove:      @escaping (CGFloat, CGFloat) -> Void,
                 onScroll:    @escaping (CGFloat, CGFloat) -> Void,
                 onTap:       @escaping () -> Void,
                 onLongPress: @escaping () -> Void) {
                self.onMove = onMove
                self.onScroll = onScroll
                self.onTap = onTap
                self.onLongPress = onLongPress
            }

            @objc func handleMove(_ pan: UIPanGestureRecognizer) {
                switch pan.state {
                case .began:
                    moveLast = .zero
                case .changed:
                    let t = pan.translation(in: pan.view)
                    let dx = t.x - moveLast.x
                    let dy = t.y - moveLast.y
                    moveLast = t
                    if dx != 0 || dy != 0 {
                        onMove(dx, dy)
                    }
                case .ended, .cancelled, .failed:
                    moveLast = .zero
                default: break
                }
            }

            @objc func handleScroll(_ pan: UIPanGestureRecognizer) {
                switch pan.state {
                case .began:
                    scrollLast = .zero
                case .changed:
                    let t = pan.translation(in: pan.view)
                    let dx = t.x - scrollLast.x
                    let dy = t.y - scrollLast.y
                    scrollLast = t
                    if dx != 0 || dy != 0 {
                        onScroll(dx, dy)
                    }
                case .ended, .cancelled, .failed:
                    scrollLast = .zero
                default: break
                }
            }

            @objc func handleTap() { onTap() }

            /// Right-click — fired by both 2-finger tap and long-press.
            @objc func handleRightClick() { onLongPress() }

            @objc func handleLongPress(_ gr: UILongPressGestureRecognizer) {
                if gr.state == .began { onLongPress() }
            }

            // The 1-finger pan and the tap recognizer normally fight: a tap
            // is a touch with zero movement, but the pan also wants to start.
            // UIKit disambiguates by waiting for movement; if there is none
            // by the time the touch ends, the tap wins. The default delegate
            // behavior already handles this — we just need to make sure all
            // recognizers can run alongside each other.
            func gestureRecognizer(
                _ g: UIGestureRecognizer,
                shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
            ) -> Bool {
                // Move + scroll need to coexist (different finger counts).
                // Tap and long-press need to coexist with the pan recognizers
                // because they all track touches that may or may not become drags.
                return true
            }
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
