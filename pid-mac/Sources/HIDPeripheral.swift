// HIDPeripheral.swift
// Stub for the Mac → Bluetooth HID keyboard peripheral mode.
// See pid-mac/BTHID-NOTES.md for the full architectural rationale.
//
// Status: SCAFFOLD ONLY. The IOBluetooth profile registration code has not
// been written yet — pair attempts will fail. Defines the protocol shape
// so the rest of the listener can already call into it behind a feature flag.

import Foundation
#if canImport(IOBluetooth)
import IOBluetooth
#endif

// MARK: - HID descriptor (standard 8-byte boot keyboard)

/// USB HID class boot keyboard descriptor — the same one a wired keyboard
/// reports. Most operating systems will accept this without a custom driver.
let kBootKeyboardDescriptor: [UInt8] = [
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x06,        // Usage (Keyboard)
    0xA1, 0x01,        // Collection (Application)
    0x05, 0x07,        //   Usage Page (Key Codes)
    0x19, 0xE0,        //   Usage Minimum (224)  -- left ctrl
    0x29, 0xE7,        //   Usage Maximum (231)  -- right gui
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x01,        //   Logical Maximum (1)
    0x75, 0x01,        //   Report Size (1)
    0x95, 0x08,        //   Report Count (8)
    0x81, 0x02,        //   Input (Data, Variable, Absolute) -- modifier byte
    0x95, 0x01,        //   Report Count (1)
    0x75, 0x08,        //   Report Size (8)
    0x81, 0x01,        //   Input (Constant) -- reserved byte
    0x95, 0x05,        //   Report Count (5)
    0x75, 0x01,        //   Report Size (1)
    0x05, 0x08,        //   Usage Page (LEDs)
    0x19, 0x01,        //   Usage Minimum (1)
    0x29, 0x05,        //   Usage Maximum (5)
    0x91, 0x02,        //   Output (Data, Variable, Absolute) -- LEDs
    0x95, 0x01,        //   Report Count (1)
    0x75, 0x03,        //   Report Size (3)
    0x91, 0x01,        //   Output (Constant) -- LED padding
    0x95, 0x06,        //   Report Count (6)
    0x75, 0x08,        //   Report Size (8)
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x65,        //   Logical Maximum (101)
    0x05, 0x07,        //   Usage Page (Key Codes)
    0x19, 0x00,        //   Usage Minimum (0)
    0x29, 0x65,        //   Usage Maximum (101)
    0x81, 0x00,        //   Input (Data, Array)
    0xC0               // End Collection
]

/// 8-byte HID input report:
///   [modifier] [reserved] [key1] [key2] [key3] [key4] [key5] [key6]
struct HIDReport {
    var modifier: UInt8 = 0
    var keys: [UInt8] = [0, 0, 0, 0, 0, 0]

    var bytes: [UInt8] { [modifier, 0] + keys }

    static let empty = HIDReport()
}

enum HIDModifier: UInt8 {
    case leftCtrl   = 0x01
    case leftShift  = 0x02
    case leftAlt    = 0x04
    case leftGUI    = 0x08
    case rightCtrl  = 0x10
    case rightShift = 0x20
    case rightAlt   = 0x40
    case rightGUI   = 0x80
}

// MARK: - Peripheral

/// API the rest of the listener will call.
protocol HIDPeripheralProtocol: AnyObject {
    /// Begin advertising as a discoverable BT HID keyboard.
    func startAdvertising() throws
    /// Stop advertising / unpair.
    func stop()
    /// Send a single HID report (key state snapshot).
    func send(_ report: HIDReport)
    /// True if any host is currently connected.
    var isConnected: Bool { get }
}

/// Stub implementation. Real impl will live here once IOBluetooth pairing
/// is wired up — see BTHID-NOTES.md.
final class BTHIDPeripheral: HIDPeripheralProtocol {

    enum BTHIDError: Error {
        case notImplemented
        case bluetoothUnavailable
        case sdpRegistrationFailed
    }

    private(set) var isConnected: Bool = false

    init() {}

    func startAdvertising() throws {
        #if canImport(IOBluetooth)
        // 1. Make sure the Bluetooth controller is powered on.
        guard let controller = IOBluetoothHostController.default(),
              controller.powerState == kBluetoothHCIPowerStateON else {
            throw BTHIDError.bluetoothUnavailable
        }

        // 2. TODO: build the SDP service record (PSM 0x11 + 0x13, HID descriptor).
        // 3. TODO: open L2CAP control + interrupt channels.
        // 4. TODO: enter discoverable mode.

        throw BTHIDError.notImplemented
        #else
        throw BTHIDError.bluetoothUnavailable
        #endif
    }

    func stop() {
        // TODO: tear down L2CAP channels and SDP record.
        isConnected = false
    }

    func send(_ report: HIDReport) {
        // TODO: write the 8-byte report to the interrupt channel.
        _ = report.bytes
    }
}

// MARK: - Bridge from wire-protocol KeyEvent to HID report

/// Map a uinput-style "KEY_X" name to the USB HID usage code (page 0x07).
/// Subset — the listener will fall back to CGEvent for anything not in the map.
let kHIDUsageByLinuxKey: [String: UInt8] = [
    "KEY_A": 0x04, "KEY_B": 0x05, "KEY_C": 0x06, "KEY_D": 0x07, "KEY_E": 0x08,
    "KEY_F": 0x09, "KEY_G": 0x0A, "KEY_H": 0x0B, "KEY_I": 0x0C, "KEY_J": 0x0D,
    "KEY_K": 0x0E, "KEY_L": 0x0F, "KEY_M": 0x10, "KEY_N": 0x11, "KEY_O": 0x12,
    "KEY_P": 0x13, "KEY_Q": 0x14, "KEY_R": 0x15, "KEY_S": 0x16, "KEY_T": 0x17,
    "KEY_U": 0x18, "KEY_V": 0x19, "KEY_W": 0x1A, "KEY_X": 0x1B, "KEY_Y": 0x1C,
    "KEY_Z": 0x1D,
    "KEY_1": 0x1E, "KEY_2": 0x1F, "KEY_3": 0x20, "KEY_4": 0x21, "KEY_5": 0x22,
    "KEY_6": 0x23, "KEY_7": 0x24, "KEY_8": 0x25, "KEY_9": 0x26, "KEY_0": 0x27,
    "KEY_ENTER": 0x28, "KEY_ESC": 0x29, "KEY_BACKSPACE": 0x2A, "KEY_TAB": 0x2B,
    "KEY_SPACE": 0x2C, "KEY_MINUS": 0x2D, "KEY_EQUAL": 0x2E,
    "KEY_LEFTBRACE": 0x2F, "KEY_RIGHTBRACE": 0x30, "KEY_BACKSLASH": 0x31,
    "KEY_SEMICOLON": 0x33, "KEY_APOSTROPHE": 0x34, "KEY_GRAVE": 0x35,
    "KEY_COMMA": 0x36, "KEY_DOT": 0x37, "KEY_SLASH": 0x38,
    "KEY_RIGHT": 0x4F, "KEY_LEFT": 0x50, "KEY_DOWN": 0x51, "KEY_UP": 0x52,
]

func hidModifierByte(from modifiers: [String]) -> UInt8 {
    var byte: UInt8 = 0
    if modifiers.contains("shift") { byte |= HIDModifier.leftShift.rawValue }
    if modifiers.contains("ctrl")  { byte |= HIDModifier.leftCtrl.rawValue }
    if modifiers.contains("alt")   { byte |= HIDModifier.leftAlt.rawValue }
    if modifiers.contains("meta")  { byte |= HIDModifier.leftGUI.rawValue }
    return byte
}
