import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: PiSession

    var body: some View {
        #if os(watchOS)
        WatchRootView()
        #else
        Group {
            if session.isConnected {
                ControlView()
            } else {
                ConnectView()
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.textPrimary)
        #endif
    }
}

#if !os(watchOS)
private struct ConnectView: View {
    @EnvironmentObject var session: PiSession
    @StateObject private var discovery = Discovery()
    @State private var manualHost: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                discoveredCard
                manualCard
                Spacer(minLength: 24)
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("piKeyboard")
                    .font(.title2.weight(.bold))
            }
            Text("Control your Raspberry Pi")
                .font(.footnote)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.top, 8)
    }

    private var discoveredCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Devices on your network").font(.subheadline.weight(.semibold))
                    Spacer()
                    if discovery.isScanning {
                        ProgressView().scaleEffect(0.7)
                    }
                }
                if discovery.devices.isEmpty {
                    Text("Searching for Pi…")
                        .font(.footnote)
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(discovery.devices) { dev in
                        Button {
                            session.connect(endpoint: dev.endpoint)
                        } label: {
                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundStyle(Theme.accent)
                                Text(dev.name)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textMuted)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Theme.surfaceHi)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var manualCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Or enter Pi IP address").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    TextField("192.168.4.1", text: $manualHost)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Theme.surfaceHi)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onChange(of: manualHost) { _, _ in session.clearError() }
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        #endif
                    Button("Connect") {
                        guard !manualHost.isEmpty else { return }
                        session.connect(host: manualHost)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                if case .error(let msg) = session.state {
                    Text(msg).font(.caption).foregroundStyle(Theme.danger)
                }
            }
        }
    }
}

private struct ControlView: View {
    @EnvironmentObject var session: PiSession
    @State private var tab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            tabBar
            content
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.success).frame(width: 8, height: 8)
            Text("Connected to \(session.host)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textMuted)
            Spacer()
            Button {
                session.disconnect()
            } label: {
                Text("Disconnect")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.surface)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.bg)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton("Trackpad", index: 0, icon: "rectangle.dashed")
            tabButton("Keyboard", index: 1, icon: "keyboard")
            tabButton("Macros",   index: 2, icon: "command")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func tabButton(_ title: String, index: Int, icon: String) -> some View {
        Button { tab = index } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title).font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(tab == index ? Theme.accentSoft : Theme.surface)
            .foregroundStyle(tab == index ? Theme.accent : Theme.textMuted)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case 0: TrackpadView()
        case 1: KeyboardView()
        default: MacrosView()
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(configuration.isPressed ? Theme.accent.opacity(0.7) : Theme.accent)
            .foregroundStyle(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
#endif
