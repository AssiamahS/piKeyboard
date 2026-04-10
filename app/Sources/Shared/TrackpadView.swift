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

    /// The Palm Pilot center scroll-ball. Acts as a **scroll joystick**:
    /// drag your thumb on the orb and the inner LED-dot follows your finger
    /// (clamped to a circle). While dragged, the orb continuously fires
    /// scroll events proportional to how far the dot is pulled from center
    /// — Angry Birds slingshot mechanics. Quick tap (no drag) = middle click.
    /// Haptic feedback scales with the tension: the further you pull, the
    /// harder the bumps. Release = spring back + success haptic.
    private func palmOrb(action: @escaping () -> Void) -> some View {
        InteractiveOrb(
            onMiddleClick: action,
            onScroll: { dx, dy in
                session.send(.scroll(dx: Double(dx), dy: Double(dy)))
            }
        )
    }
}

#if os(iOS)
/// Interactive Palm-Pilot-style scroll ball. The "LED" inside is a real
/// physics-y dot that follows your thumb, fires scroll events while held,
/// and snaps back on release. Continuous haptic ramp as you stretch.
private struct InteractiveOrb: View {
    let onMiddleClick: () -> Void
    let onScroll: (CGFloat, CGFloat) -> Void

    @State private var dotOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var lastZone: Int = 0
    @State private var scrollTimer: Timer?

    private let orbSize: CGFloat = 64
    /// Maximum distance the dot can be pulled from center.
    private let maxRadius: CGFloat = 18
    /// Idle resting position of the LED (the static spec from earlier).
    private let restingOffset = CGSize(width: -10, height: -10)

    var body: some View {
        ZStack {
            // Orb body — same look as v0.2.6 palmOrb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.22), Color(white: 0.06)],
                        center: .init(x: 0.35, y: 0.35),
                        startRadius: 2, endRadius: 38
                    )
                )
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.black.opacity(0.45)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.4
                    )
                )

            // Decorative inner ring
            Circle()
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
                .frame(width: 22, height: 22)

            // The interactive dot — grows + brightens while dragging
            Circle()
                .fill(Theme.accent.opacity(isDragging ? 0.95 : 0.55))
                .shadow(
                    color: Theme.accent.opacity(isDragging ? 0.6 : 0),
                    radius: isDragging ? 4 : 0
                )
                .frame(
                    width: isDragging ? 6 : 3.5,
                    height: isDragging ? 6 : 3.5
                )
                .offset(isDragging ? dotOffset : restingOffset)
                .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.7),
                           value: dotOffset)
                .animation(.easeOut(duration: 0.22), value: isDragging)
        }
        .frame(width: orbSize, height: orbSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    handleDragChanged(v.translation)
                }
                .onEnded { v in
                    handleDragEnded(v.translation)
                }
        )
    }

    // MARK: - Gesture handling

    private func handleDragChanged(_ raw: CGSize) {
        let dist = hypot(raw.width, raw.height)

        if !isDragging {
            // Decide if this is a tap or a drag
            if dist < 4 { return }
            isDragging = true
            UISelectionFeedbackGenerator().selectionChanged()
            startScrollTimer()
        }

        // Clamp the dot to the orb radius
        let clamped: CGSize
        if dist > maxRadius {
            let scale = maxRadius / dist
            clamped = CGSize(width: raw.width * scale, height: raw.height * scale)
        } else {
            clamped = raw
        }
        dotOffset = clamped

        // Tension haptic — fire when crossing into a new "zone" further out.
        // 5 zones = 0..4. The further you pull, the heavier the bump.
        let normalizedDist = min(dist, maxRadius) / maxRadius
        let zone = Int(normalizedDist * 5)
        if zone != lastZone && zone > 0 {
            let style: UIImpactFeedbackGenerator.FeedbackStyle
            switch zone {
            case 1: style = .light
            case 2: style = .light
            case 3: style = .medium
            default: style = .heavy
            }
            let gen = UIImpactFeedbackGenerator(style: style)
            gen.impactOccurred(intensity: CGFloat(normalizedDist))
        }
        lastZone = zone
    }

    private func handleDragEnded(_ raw: CGSize) {
        if !isDragging {
            // No drag happened — it was a tap. Fire middle click.
            onMiddleClick()
            return
        }
        // Snap back with a satisfying notification haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        stopScrollTimer()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) {
            dotOffset = .zero
        }
        // Wait for the spring animation, then return to resting state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            isDragging = false
            lastZone = 0
        }
    }

    // MARK: - Continuous scroll while held

    private func startScrollTimer() {
        scrollTimer?.invalidate()
        // Fire ~16Hz scroll events while the dot is held off-center
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            // Map dot offset to wheel ticks. dotOffset.height positive = down,
            // we want that to scroll page down → negative wheel.
            let speedY = -Double(dotOffset.height) / 6
            let speedX = Double(dotOffset.width) / 6
            if abs(speedX) > 0.15 || abs(speedY) > 0.15 {
                onScroll(CGFloat(speedX), CGFloat(speedY))
            }
        }
    }

    private func stopScrollTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
}
#endif

extension TrackpadView {

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

            func gestureRecognizer(
                _ g: UIGestureRecognizer,
                shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
            ) -> Bool {
                // CRITICAL: 1-finger pan and 2-finger pan must NOT run
                // simultaneously. They both track touches and would stomp
                // on each other's translation state, which manifested in
                // v0.2.6 as the trackpad freezing during 2-finger scroll.
                if let p1 = g as? UIPanGestureRecognizer,
                   let p2 = other as? UIPanGestureRecognizer,
                   p1.maximumNumberOfTouches != p2.maximumNumberOfTouches {
                    return false
                }
                // Everything else can coexist (taps, long-press, the
                // pan that's actually active for the current touch count).
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
