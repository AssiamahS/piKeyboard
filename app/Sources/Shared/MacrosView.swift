import SwiftUI

#if !os(watchOS)
struct MacrosView: View {
    @EnvironmentObject var session: PiSession

    private struct Macro: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let run: (PiSession) -> Void
    }

    private var macros: [Macro] {
        [
            Macro(title: "Reboot", icon: "arrow.clockwise") { s in
                s.type("sudo reboot\n")
            },
            Macro(title: "Shutdown", icon: "power") { s in
                s.type("sudo shutdown -h now\n")
            },
            Macro(title: "Top", icon: "chart.bar") { s in
                s.type("htop\n")
            },
            Macro(title: "Clear", icon: "eraser") { s in
                s.tap("KEY_L", modifiers: ["ctrl"])
            },
            Macro(title: "Cancel", icon: "xmark.circle") { s in
                s.tap("KEY_C", modifiers: ["ctrl"])
            },
            Macro(title: "Tab Complete", icon: "arrow.right.to.line") { s in
                s.tap("KEY_TAB")
            },
        ]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: 12)],
                spacing: 12
            ) {
                ForEach(macros) { m in
                    Button {
                        m.run(session)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: m.icon)
                                .font(.title2)
                                .foregroundStyle(Theme.accent)
                            Text(m.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                                .stroke(Theme.stroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
}
#endif
