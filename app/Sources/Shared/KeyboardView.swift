import SwiftUI

#if !os(watchOS)
/// Pro layout: iOS native keyboard for actual typing + a toolbar above the
/// keyboard with a mini trackpad strip and L/R buttons. Same model Mobile Mouse
/// Pro and Air Mouse use — let the OS handle text input, give the user click
/// access without dismissing the keyboard.
struct KeyboardView: View {
    @EnvironmentObject var session: PiSession
    @State private var input: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            instructions
            Spacer(minLength: 0)
            textField
            quickRow
        }
        .background(Theme.bg)
        .onAppear {
            // Auto-summon the iOS keyboard when the user lands on this tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focused = true
            }
        }
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                keyboardAccessoryBar
            }
        }
        #endif
    }

    // MARK: - Pieces

    private var instructions: some View {
        VStack(spacing: 6) {
            Image(systemName: "keyboard")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("Type to send")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Anything you type goes to the Pi.\nUse the bar above the keyboard for clicks and shortcuts.")
                .multilineTextAlignment(.center)
                .font(.footnote)
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, 32)
        }
    }

    private var textField: some View {
        HStack(spacing: 8) {
            TextField("Type here…", text: $input)
                .focused($focused)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.send)
                #endif
                .onChange(of: input) { _, new in
                    // Stream every keystroke to the Pi as it's typed.
                    if !new.isEmpty {
                        session.type(new)
                        input = ""
                    }
                }
                .onSubmit(sendEnter)
            Button(action: sendEnter) {
                Image(systemName: "return")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    /// One-tap quick keys above the text field — the moves you actually need
    /// in a terminal session that the iOS keyboard can't produce.
    private var quickRow: some View {
        HStack(spacing: 6) {
            quickKey("esc")  { session.tap("KEY_ESC") }
            quickKey("tab")  { session.tap("KEY_TAB") }
            quickKey("⌫")    { session.tap("KEY_BACKSPACE") }
            quickKey("⏎")    { session.tap("KEY_ENTER") }
            quickKey("^C")   { session.tap("KEY_C", modifiers: ["ctrl"]) }
            quickKey("^L")   { session.tap("KEY_L", modifiers: ["ctrl"]) }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    /// Sleek bar that lives above the iOS keyboard. Mini trackpad on the left,
    /// L/R click buttons on the right. Lets you click while typing.
    @ViewBuilder
    private var keyboardAccessoryBar: some View {
        #if os(iOS)
        HStack(spacing: 8) {
            MiniTrackpad()
                .environmentObject(session)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            Button {
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: true)))
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "left", down: false)))
            } label: {
                Image(systemName: "cursorarrow.click")
                    .frame(width: 38, height: 36)
            }
            .buttonStyle(.plain)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Button {
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "right", down: true)))
                session.send(.mouse(MouseEvent(dx: 0, dy: 0, button: "right", down: false)))
            } label: {
                Image(systemName: "cursorarrow.click.2")
                    .frame(width: 38, height: 36)
            }
            .buttonStyle(.plain)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        #else
        EmptyView()
        #endif
    }

    private func quickKey(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Theme.surface)
                .foregroundStyle(Theme.textMuted)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func sendEnter() {
        session.tap("KEY_ENTER")
    }
}

#if os(iOS)
/// Tiny trackpad strip used inside the iOS keyboard accessory bar. Pure drag
/// translation → REL_X/REL_Y. No click — that's what the buttons next to it do.
private struct MiniTrackpad: View {
    @EnvironmentObject var session: PiSession
    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Theme.surface)
            .overlay(
                Image(systemName: "rectangle.dashed")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { v in
                        let dx = v.translation.width  - lastTranslation.width
                        let dy = v.translation.height - lastTranslation.height
                        lastTranslation = v.translation
                        // Mini-pad is small, scale up for usability
                        let scale = 1.6
                        if dx != 0 || dy != 0 {
                            session.send(.mouse(MouseEvent(
                                dx: Double(dx) * scale,
                                dy: Double(dy) * scale,
                                button: nil, down: nil)))
                        }
                    }
                    .onEnded { _ in lastTranslation = .zero }
            )
    }
}
#endif
#endif
