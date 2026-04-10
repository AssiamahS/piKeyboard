# piKeyboard

Modern, minimal remote keyboard + trackpad for **Raspberry Pi 5** and **Mac**, with clients for **iPhone, iPad, Mac, and Apple Watch**.

Inspired by Mobile Mouse and Typeeto, but free and open. Designed to replace the dated Remote Pi / RaspController / SimplePi apps with something that actually looks like a 2026 product.

## What it does

- **Pi5 in Wi-Fi hotspot mode** — your phone joins the Pi's AP, no router needed
- **USB tether fallback** — same protocol over the iPhone↔Pi USB-C link
- **Trackpad + keyboard + macros** for the Pi (or any Mac)
- **Bonjour discovery** (`_pikeyboard._tcp`) so the app finds the device automatically
- **Bidirectional today:** any controller (iPhone/iPad/Mac/Watch) → Pi or Mac. iPhone/iPad as a *target* is planned for v0.2 via Bluetooth HID peripheral mode.

## Repo layout

```
app/             SwiftUI multiplatform client (iOS + iPad + macOS + watchOS)
  project.yml    XcodeGen — single source of truth for the Xcode project
  Sources/Shared SwiftUI views + protocol + Bonjour discovery + WebSocket session
  Sources/iOS    iOS Info.plist
  Sources/macOS  macOS Info.plist
  Sources/watchOS watchOS Info.plist

pid/             Raspberry Pi daemon (Python + uinput)
  pikeyboard_daemon.py
  install.sh
  systemd/pikeyboard.service
  requirements.txt

pid-mac/         macOS listener — lets your Mac act as a target via CGEvent
  Package.swift
  Sources/main.swift
```

## Build

### Apple clients
```
brew install xcodegen
cd app
xcodegen generate
open piKeyboard.xcodeproj
```
Or from CLI:
```
xcodebuild -project app/piKeyboard.xcodeproj -scheme piKeyboard-iOS \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -project app/piKeyboard.xcodeproj -scheme piKeyboard-macOS build
```

### Mac listener
```
cd pid-mac
swift build -c release
.build/release/pikeyboardd
```
Grant Accessibility permission in **System Settings → Privacy & Security → Accessibility** for whichever terminal you ran it from.

### Raspberry Pi daemon

One-line install on the Pi:
```
curl -fsSL https://raw.githubusercontent.com/AssiamahS/piKeyboard/main/pid/install.sh | sudo bash
```

What it does:
- Installs `python3-venv`, `git`, `avahi-daemon`
- Loads the `uinput` kernel module + persists it
- Clones this repo into `/opt/pikeyboard`
- Installs the venv + Python deps
- Drops a systemd unit (`pikeyboard.service`) and starts it

Verify:
```
systemctl status pikeyboard
journalctl -u pikeyboard -f
dns-sd -B _pikeyboard._tcp     # from a Mac on the same network
```

## Wire protocol

Newline-delimited JSON. Same shape on every transport (WebSocket on the Pi, raw TCP on the Mac listener).

```json
{"t":"hello","p":{"client":"iOS","version":"0.1.0"}}
{"t":"key","p":{"code":"KEY_ENTER","down":true,"modifiers":[]}}
{"t":"key","p":{"code":"KEY_ENTER","down":false,"modifiers":[]}}
{"t":"text","p":{"s":"hello world"}}
{"t":"mouse","p":{"dx":12,"dy":-4}}
{"t":"mouse","p":{"dx":0,"dy":0,"button":"left","down":true}}
{"t":"scroll","p":{"dx":0,"dy":-3}}
{"t":"ping"}
```

Key codes follow Linux `uinput` `KEY_*` naming. The Mac listener maps them to CGKeyCodes.

## Development

- **Bump version on every release.** `app/project.yml` has `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Bump both, regenerate, commit, tag.
- **No code signing in CI** — `project.yml` sets `CODE_SIGN_IDENTITY=""` so anyone can build without certs.
- **Test the Pi daemon on your Mac first** with `PIKEYBOARD_FAKE=1 ./pid/pikeyboard_daemon.py` — it logs every event instead of injecting.

## Roadmap

- [x] v0.1 — controller (iPhone/iPad/Mac/Watch) → Pi or Mac
- [ ] v0.2 — iPhone/iPad as **target** via CoreBluetooth HID peripheral
- [ ] v0.3 — paste history, clipboard sync
- [ ] v0.4 — multi-device profiles, per-device keymaps
- [ ] v0.5 — Pi5 hotspot setup wizard inside the iOS app
```
