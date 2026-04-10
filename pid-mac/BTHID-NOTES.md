# BT HID peripheral on macOS — research notes

## Goal

Make a Mac running piKeyboard advertise itself as a **Bluetooth HID
keyboard**, so iPhone, iPad, Apple TV, Vision Pro, Quest, and any other BT-HID
host can pair to it. Once paired, every keystroke piKeyboard injects into the
Mac listener gets forwarded out the Bluetooth radio as a real HID report.

This is the **Typeeto / KeyPad model** (Mac → BT HID → other device).

## Why this is hard

There are two transport options for BT HID on a Mac:

### 1. Bluetooth Classic (BR/EDR) — IOBluetooth framework
- The legacy API Apple ships, used by Typeeto and KeyPad.
- Public APIs exist for *consuming* HID devices (`IOBluetoothHIDDevice`) but
  the APIs for *advertising as* a HID device require setting up an
  L2CAP-based SDP service record + HID profile descriptor manually.
- Apple **deprecated several IOBluetooth advertising APIs** in macOS 11+ but
  they still work in current macOS (26.x). Long-term fragile.
- Typeeto uses these and ships on the Mac App Store, so it is possible
  with a sandbox entitlement and the right SDP record.

### 2. Bluetooth Low Energy (BLE) HID-over-GATT — CoreBluetooth peripheral mode
- The modern, BLE-based standard. Service UUID `0x1812` (HID Service).
- macOS' `CBPeripheralManager` **cannot advertise the HID service UUID** —
  Apple restricts that UUID to the system Bluetooth stack so third-party
  apps can't impersonate keyboards over BLE.
- iOS has the same restriction.
- Therefore: **HOGP via CoreBluetooth is a dead end on Apple platforms.**

## Practical paths

| Path | Effort | Reliability | Notes |
|---|---|---|---|
| IOBluetooth classic (Typeeto-style) | High | Medium (deprecated APIs) | Most likely to actually work |
| CoreBluetooth HOGP | N/A | 0 | Apple blocks the HID UUID |
| External BT HID dongle (e.g., USB → BLE HID adapter) | Low | High | Hardware dependency |
| Bluefruit/RPi as HID intermediary | Medium | High | Adds a hop |
| Just use the Wi-Fi WebSocket protocol piKeyboard already has | Already done | High | Doesn't work for non-piKeyboard targets |

## Recommended scaffold

For v0.3:

1. Add a `BTHIDPeripheral` Swift class in `pid-mac/Sources/HIDPeripheral.swift`
   that implements the IOBluetooth-classic path. Behind a `--bluetooth` CLI flag.
2. Define the standard 8-byte HID keyboard report descriptor.
3. On `key down/up` events from the WebSocket, build a HID report and
   send it over the L2CAP HID Interrupt channel.
4. Provide a CLI arg `pikeyboardd --bluetooth --pairable` that enters
   discoverable mode for 30 seconds.
5. Document: "this requires the Mac to be in pairable mode and the
   target device to initiate pairing."

For v0.4 (if v0.3 is fragile):

- Pivot to using a **Raspberry Pi Zero W** as a USB-OTG HID intermediary.
  Plug the Pi Zero into the target device's USB port — it already
  presents as a HID keyboard via Linux's `libcomposite` USB gadget mode,
  which we already use for the main Pi 5 daemon. Then Mac → WebSocket →
  Pi Zero → USB HID → target.
- This gives a hardware-backed, reliable path that doesn't depend on
  Apple's wireless stack at all.

## What this scaffold does NOT do yet

- It does **not** actually pair anything yet.
- The IOBluetooth profile registration is stubbed out — the real work
  is constructing the SDP service record dictionary and the HID
  descriptor in the exact format Apple's stack expects, which requires
  testing against a real iPhone in pair mode.
- No code-signing entitlements added (sandbox + Bluetooth entitlements
  required for App Store distribution).

## Next session

1. Add `com.apple.security.device.bluetooth` entitlement to pid-mac.
2. Use `IOBluetoothHostController.default()` to get the local controller.
3. Build the SDP record (PSM 0x11 control, 0x13 interrupt, HID descriptor list).
4. Open L2CAP channels via `IOBluetoothL2CAPChannel`.
5. Test against an iPad Pro (most forgiving for pairing).
6. If pairing succeeds, send a "Hello" HID report and verify it appears
   in a focused Notes app on the iPad.

## References

- [Bluetooth HID Profile 1.0](https://www.bluetooth.com/specifications/specs/human-interface-device-profile-1-0/)
- [USB HID Usage Tables](https://usb.org/document-library/hid-usage-tables-15)
- IOBluetooth headers: `/Library/Frameworks/IOBluetooth.framework/Headers/`
- Typeeto blog post on technique: search "typeeto bluetooth keyboard mac"
