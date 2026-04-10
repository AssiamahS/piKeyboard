import SwiftUI

#if !os(watchOS)
struct KeyboardView: View {
    @EnvironmentObject var session: PiSession
    @State private var input: String = ""
    @State private var shift = false
    @State private var ctrl  = false
    @State private var alt   = false
    @State private var meta  = false

    private let row1 = ["1","2","3","4","5","6","7","8","9","0"]
    private let row2 = ["q","w","e","r","t","y","u","i","o","p"]
    private let row3 = ["a","s","d","f","g","h","j","k","l"]
    private let row4 = ["z","x","c","v","b","n","m"]

    var body: some View {
        VStack(spacing: 10) {
            textField
            modifierBar
            keyRow(row1)
            keyRow(row2)
            keyRow(row3)
            HStack(spacing: 6) {
                modKey("⇧", on: $shift)
                ForEach(row4, id: \.self) { k in keyButton(k) }
                specialKey("⌫") { session.tap("KEY_BACKSPACE") }
            }
            HStack(spacing: 6) {
                specialKey("tab", flex: 1) { session.tap("KEY_TAB") }
                specialKey("space", flex: 4) { session.tap("KEY_SPACE") }
                specialKey("⏎", flex: 1) { session.tap("KEY_ENTER") }
            }
            arrowPad
        }
        .padding(12)
    }

    private var textField: some View {
        HStack(spacing: 8) {
            TextField("Type here, hit send →", text: $input)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
                .onSubmit(sendText)
            Button(action: sendText) {
                Image(systemName: "paperplane.fill")
                    .padding(10)
                    .background(Theme.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func sendText() {
        guard !input.isEmpty else { return }
        session.type(input)
        input = ""
    }

    private var modifierBar: some View {
        HStack(spacing: 6) {
            modKey("⌃", on: $ctrl)
            modKey("⌥", on: $alt)
            modKey("⌘", on: $meta)
            specialKey("esc") { session.tap("KEY_ESC") }
        }
    }

    private func keyRow(_ keys: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(keys, id: \.self) { k in keyButton(k) }
        }
    }

    private func keyButton(_ k: String) -> some View {
        Button {
            session.tap("KEY_\(k.uppercased())", modifiers: activeMods())
        } label: {
            Text(shift ? k.uppercased() : k)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
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

    private func modKey(_ label: String, on: Binding<Bool>) -> some View {
        Button {
            on.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(on.wrappedValue ? Theme.accentSoft : Theme.surface)
                .foregroundStyle(on.wrappedValue ? Theme.accent : Theme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusKey, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusKey, style: .continuous)
                        .stroke(on.wrappedValue ? Theme.accent.opacity(0.6) : Theme.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func specialKey(_ label: String, flex: CGFloat = 1, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.surface)
                .foregroundStyle(Theme.textMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusKey, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusKey, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .layoutPriority(flex)
    }

    private var arrowPad: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Spacer()
                arrow("KEY_UP", system: "chevron.up")
                Spacer()
            }
            HStack(spacing: 6) {
                arrow("KEY_LEFT", system: "chevron.left")
                arrow("KEY_DOWN", system: "chevron.down")
                arrow("KEY_RIGHT", system: "chevron.right")
            }
        }
        .padding(.top, 6)
    }

    private func arrow(_ code: String, system: String) -> some View {
        Button { session.tap(code) } label: {
            Image(systemName: system)
                .font(.body.weight(.semibold))
                .frame(width: 60, height: 44)
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

    private func activeMods() -> [String] {
        var m: [String] = []
        if shift { m.append("shift") }
        if ctrl  { m.append("ctrl")  }
        if alt   { m.append("alt")   }
        if meta  { m.append("meta")  }
        return m
    }
}
#endif
