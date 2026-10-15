// Mac Android Subsystem - the view that shows one Android app's virtual display
// and turns Mac input into Android input.
//
// Mouse: left button = finger touch (scrcpy maps the "mouse" pointer with only the
// primary button to a touchscreen event), right button = mouse secondary click,
// trackpad and wheel = scroll, hover = mouse hover.
// Keyboard: text goes as text, everything else as keycodes (AndroidKeys).
//
// Licensed under the GNU General Public License v3 or later.

import AppKit
import AVFoundation

final class AndroidDisplayView: NSView {
    weak var session: ScrcpySession?
    /// Size of the Android frame in pixels; input coordinates are scaled to it.
    var frameSize = CGSize(width: 1, height: 1)
    /// Called when the view's pixel size settles after a resize.
    var onPixelSizeChange: ((Int, Int) -> Void)?

    let displayLayer = AVSampleBufferDisplayLayer()
    private var trackingArea: NSTrackingArea?
    private var buttons: UInt32 = 0
    private var resizeWork: DispatchWorkItem?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        displayLayer.videoGravity = .resizeAspect
        displayLayer.frame = bounds
        displayLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Video

    func enqueue(_ sample: CMSampleBuffer) {
        if #available(macOS 15.0, *) {
            let renderer = displayLayer.sampleBufferRenderer
            if renderer.status == .failed {
                renderer.flush()
                session?.resetVideo()
            }
            renderer.enqueue(sample)
        } else {
            if displayLayer.status == .failed {
                displayLayer.flush()
                session?.resetVideo()
            }
            displayLayer.enqueue(sample)
        }
    }

    func flushVideo() {
        if #available(macOS 15.0, *) {
            displayLayer.sampleBufferRenderer.flush()
        } else {
            displayLayer.flush()
        }
    }

    // MARK: Size

    var pixelSize: (width: Int, height: Int) {
        let scale = window?.backingScaleFactor ?? 2
        return (Int((bounds.width * scale).rounded()), Int((bounds.height * scale).rounded()))
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        CATransaction.commit()
        // Debounce: the virtual display is resized once the window stops moving for a moment.
        resizeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let size = self.pixelSize
            self.onPixelSizeChange?(size.width, size.height)
        }
        resizeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    /// Map a point in the view to Android pixels, honouring the aspect-fit letterbox.
    private func androidPoint(_ event: NSEvent) -> (Int, Int)? {
        let point = convert(event.locationInWindow, from: nil)
        let video = AVMakeRect(aspectRatio: frameSize, insideRect: bounds)
        guard video.width > 0, video.height > 0 else { return nil }
        let x = (point.x - video.minX) / video.width * frameSize.width
        let y = (point.y - video.minY) / video.height * frameSize.height
        return (Int(max(0, min(frameSize.width - 1, x))), Int(max(0, min(frameSize.height - 1, y))))
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let (x, y) = androidPoint(event) else { return }
        buttons |= ScrcpySession.buttonPrimary
        session?.injectTouch(.down, x: x, y: y, actionButton: ScrcpySession.buttonPrimary, buttons: buttons)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let (x, y) = androidPoint(event) else { return }
        session?.injectTouch(.move, x: x, y: y, buttons: buttons)
    }

    override func mouseUp(with event: NSEvent) {
        guard let (x, y) = androidPoint(event) else { return }
        buttons &= ~ScrcpySession.buttonPrimary
        session?.injectTouch(.up, x: x, y: y, actionButton: ScrcpySession.buttonPrimary, buttons: buttons)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let (x, y) = androidPoint(event) else { return }
        buttons |= ScrcpySession.buttonSecondary
        session?.injectTouch(.down, x: x, y: y, actionButton: ScrcpySession.buttonSecondary, buttons: buttons)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard let (x, y) = androidPoint(event) else { return }
        buttons &= ~ScrcpySession.buttonSecondary
        session?.injectTouch(.up, x: x, y: y, actionButton: ScrcpySession.buttonSecondary, buttons: buttons)
    }

    override func mouseMoved(with event: NSEvent) {
        guard buttons == 0, let (x, y) = androidPoint(event) else { return }
        session?.injectTouch(.hoverMove, x: x, y: y, pressure: 0)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let (x, y) = androidPoint(event) else { return }
        // Trackpads report precise point deltas; wheels report lines.
        let divisor: CGFloat = event.hasPreciseScrollingDeltas ? 30 : 1
        let h = Float(event.scrollingDeltaX / divisor)
        let v = Float(event.scrollingDeltaY / divisor)
        guard h != 0 || v != 0 else { return }
        session?.injectScroll(x: x, y: y, hScroll: h, vScroll: v)
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if let text = AndroidKeys.text(for: event) {
            session?.injectText(text)
            return
        }
        guard let code = AndroidKeys.keycodes[Int(event.keyCode)] else { return }
        session?.injectKey(.down, keycode: code, repeat: event.isARepeat ? 1 : 0,
                           metaState: AndroidKeys.metaState(event.modifierFlags))
    }

    override func keyUp(with event: NSEvent) {
        if AndroidKeys.text(for: event) != nil { return }
        guard let code = AndroidKeys.keycodes[Int(event.keyCode)] else { return }
        session?.injectKey(.up, keycode: code, metaState: AndroidKeys.metaState(event.modifierFlags))
    }

    /// Control-key shortcuts reach keyDown; Command shortcuts are menu items (Edit menu).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control), !flags.contains(.command), window?.firstResponder === self {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
