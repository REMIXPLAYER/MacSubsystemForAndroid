// Mac Subsystem for Android - Mac game controllers in Android games.
//
// Any controller macOS supports (Xbox, PlayStation, Switch Pro, MFi...) is
// re-created inside Android as a virtual HID gamepad through scrcpy's UHID
// messages, using scrcpy's own gamepad report descriptor (it appears in Android
// as an "Xbox 360 pad", which every Android game understands). The scrcpy server
// ties these devices to this window's display, so the game in front gets them.
//
// Devices exist only while this window is the key window, so with several
// Android apps open, the controller drives the one you're looking at.
//
// Report (15 bytes, little-endian): left x/y, right x/y (0...65535, centre
// 0x8000), L2/R2 (0...32767), 16 buttons, hat switch (0 = centred, 1 = up,
// clockwise to 8 = up-left). See scrcpy's app/src/hid/hid_gamepad.c.
//
// Licensed under the GNU General Public License v3 or later.

import Foundation
import GameController

@MainActor
final class GamepadBridge {
    weak var session: ScrcpySession? {
        didSet { if session == nil { active = false; slots.removeAll() } }
    }
    private var slots: [ObjectIdentifier: UInt16] = [:]
    private var active = false
    private var observers: [NSObjectProtocol] = []
    /// Called when the number of connected controllers changes (for the window's toolbar badge).
    var onChange: ((Int) -> Void)?

    static let firstID: UInt16 = 3       // scrcpy's SC_HID_ID_GAMEPAD_FIRST
    static let maxControllers = 8

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor [weak self] in self?.attach(controller) }
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor [weak self] in self?.detach(controller) }
        })
    }

    var connectedCount: Int { GCController.controllers().filter { $0.extendedGamepad != nil }.count }

    /// The window became key and its Android display is streaming.
    func activate() {
        guard !active, session != nil, Self.enabled else { return }
        active = true
        GCController.controllers().forEach(attach)
        onChange?(connectedCount)
    }

    /// The window lost focus or closed: remove the devices from Android.
    func deactivate() {
        guard active else { return }
        for (_, id) in slots { session?.uhidDestroy(id: id) }
        for controller in GCController.controllers() { controller.extendedGamepad?.valueChangedHandler = nil }
        slots.removeAll()
        active = false
    }

    private static var enabled: Bool {
        UserDefaults(suiteName: AppConfig.subsystemBundleID)?.object(forKey: "controllers") as? Bool ?? true
    }

    private func attach(_ controller: GCController) {
        onChange?(connectedCount)
        guard active, let session, let gamepad = controller.extendedGamepad,
              slots[ObjectIdentifier(controller)] == nil, slots.count < Self.maxControllers else { return }
        let used = Set(slots.values)
        guard let id = (0..<UInt16(Self.maxControllers)).map({ Self.firstID + $0 }).first(where: { !used.contains($0) }) else { return }
        slots[ObjectIdentifier(controller)] = id
        session.uhidCreate(id: id, vendorID: 0x045e, productID: 0x028e,
                           name: "Microsoft X-Box 360 Pad", reportDescriptor: Self.reportDescriptor)
        gamepad.valueChangedHandler = { [weak self] pad, _ in
            let report = GamepadBridge.report(for: pad)
            Task { @MainActor in self?.session?.uhidInput(id: id, report: report) }
        }
        session.uhidInput(id: id, report: Self.report(for: gamepad))
    }

    private func detach(_ controller: GCController) {
        onChange?(connectedCount)
        guard let id = slots.removeValue(forKey: ObjectIdentifier(controller)) else { return }
        session?.uhidDestroy(id: id)
    }

    // MARK: HID

    /// scrcpy's gamepad report descriptor (app/src/hid/hid_gamepad.c).
    static let reportDescriptor = Data([
        0x05, 0x01, 0x09, 0x05,             // Usage Page (Generic Desktop), Usage (Game Pad)
        0xA1, 0x01, 0xA1, 0x00,             // Collection (Application), Collection (Physical)
        0x05, 0x01, 0x09, 0x30, 0x09, 0x31, 0x09, 0x33, 0x09, 0x34, // X, Y, Rx, Ry
        0x15, 0x00, 0x27, 0xFF, 0xFF, 0x00, 0x00, 0x75, 0x10, 0x95, 0x04, 0x81, 0x02,
        0x05, 0x01, 0x09, 0x32, 0x09, 0x35, // Z, Rz (triggers)
        0x15, 0x00, 0x26, 0xFF, 0x7F, 0x75, 0x10, 0x95, 0x02, 0x81, 0x02,
        0x05, 0x09, 0x19, 0x01, 0x29, 0x10, // Buttons 1...16
        0x15, 0x00, 0x25, 0x01, 0x95, 0x10, 0x75, 0x01, 0x81, 0x02,
        0x05, 0x01, 0x09, 0x39,             // Hat switch
        0x15, 0x01, 0x25, 0x08, 0x75, 0x04, 0x95, 0x01, 0x81, 0x42,
        0xC0, 0xC0,
    ])

    nonisolated static func report(for pad: GCExtendedGamepad) -> Data {
        func axis(_ value: Float) -> UInt16 {
            let clamped = max(-1, min(1, value))
            return UInt16(Int32(clamped * 32767) + 0x8000)
        }
        func trigger(_ value: Float) -> UInt16 { UInt16(max(0, min(1, value)) * 32767) }

        var buttons: UInt16 = 0
        func set(_ pressed: Bool, _ bit: UInt16) { if pressed { buttons |= bit } }
        set(pad.buttonA.isPressed, 0x0001)                       // south
        set(pad.buttonB.isPressed, 0x0002)                       // east
        set(pad.buttonX.isPressed, 0x0008)                       // west
        set(pad.buttonY.isPressed, 0x0010)                       // north
        set(pad.leftShoulder.isPressed, 0x0040)
        set(pad.rightShoulder.isPressed, 0x0080)
        set(pad.buttonOptions?.isPressed ?? false, 0x0400)       // back / select
        set(pad.buttonMenu.isPressed, 0x0800)                    // start
        set(pad.buttonHome?.isPressed ?? false, 0x1000)          // guide
        set(pad.leftThumbstickButton?.isPressed ?? false, 0x2000)
        set(pad.rightThumbstickButton?.isPressed ?? false, 0x4000)

        let up = pad.dpad.up.isPressed, down = pad.dpad.down.isPressed
        let left = pad.dpad.left.isPressed, right = pad.dpad.right.isPressed
        var hat: UInt8 = 0
        if up { hat = left ? 8 : right ? 2 : 1 }
        else if down { hat = left ? 6 : right ? 4 : 5 }
        else if left { hat = 7 }
        else if right { hat = 3 }

        var data = Data(capacity: 15)
        // Game Controller's y axes point up; HID's point down.
        for value in [axis(pad.leftThumbstick.xAxis.value), axis(-pad.leftThumbstick.yAxis.value),
                      axis(pad.rightThumbstick.xAxis.value), axis(-pad.rightThumbstick.yAxis.value),
                      trigger(pad.leftTrigger.value), trigger(pad.rightTrigger.value), buttons] {
            data.append(UInt8(value & 0xff))
            data.append(UInt8(value >> 8))
        }
        data.append(hat)
        return data
    }
}
