// Mac Subsystem for Android - the menu bar icon: a small Android robot head, drawn
// as a template image so it follows the menu bar's colour.
//
//   running             solid head
//   starting, stopping  dimmed solid head
//   off, not set up     outlined head
//   failed              outlined head with an exclamation mark
//
// The Android robot is reproduced or modified from work created and shared by
// Google and used according to terms described in the Creative Commons 3.0
// Attribution License.
//
// Licensed under the GNU General Public License v3 or later.

import AppKit

enum MenuBarIcon {
    enum Style { case solid, dimmed, outline, warning }

    static func style(for state: Subsystem.State) -> Style {
        switch state {
        case .running: return .solid
        case .starting, .stopping: return .dimmed
        case .failed: return .warning
        case .off, .notInstalled: return .outline
        }
    }

    static func image(for state: Subsystem.State) -> NSImage {
        image(style: style(for: state))
    }

    static func image(style: Style, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width / 18
            let center = NSPoint(x: 9 * s, y: 3.5 * s)
            let radius = 7.2 * s

            // The dome of the head.
            let dome = NSBezierPath()
            dome.move(to: NSPoint(x: center.x - radius, y: center.y))
            dome.appendArc(withCenter: center, radius: radius, startAngle: 180, endAngle: 0, clockwise: true)
            dome.close()

            // Antennae, leaning outwards from the top of the dome.
            let antennae = NSBezierPath()
            for side: CGFloat in [-1, 1] {
                let angle: CGFloat = .pi / 180 * (side < 0 ? 122 : 58)
                antennae.move(to: NSPoint(x: center.x + cos(angle) * (radius - 1.2 * s), y: center.y + sin(angle) * (radius - 1.2 * s)))
                antennae.line(to: NSPoint(x: center.x + cos(angle) * (radius + 3.2 * s), y: center.y + sin(angle) * (radius + 3.2 * s)))
            }
            antennae.lineWidth = 1.5 * s
            antennae.lineCapStyle = .round

            let eyeRadius = 0.95 * s
            let eyes = [NSPoint(x: center.x - 3.1 * s, y: center.y + 2.9 * s),
                        NSPoint(x: center.x + 3.1 * s, y: center.y + 2.9 * s)]

            let alpha: CGFloat = style == .dimmed ? 0.45 : 1
            NSColor.black.withAlphaComponent(alpha).set()
            antennae.stroke()

            switch style {
            case .solid, .dimmed:
                // Solid head with the eyes cut out.
                let head = dome.copy() as! NSBezierPath
                for eye in eyes {
                    head.appendOval(in: NSRect(x: eye.x - eyeRadius, y: eye.y - eyeRadius, width: eyeRadius * 2, height: eyeRadius * 2))
                }
                head.windingRule = .evenOdd
                head.fill()
            case .outline, .warning:
                dome.lineWidth = 1.4 * s
                dome.stroke()
                if style == .outline {
                    for eye in eyes {
                        NSBezierPath(ovalIn: NSRect(x: eye.x - eyeRadius, y: eye.y - eyeRadius,
                                                    width: eyeRadius * 2, height: eyeRadius * 2)).fill()
                    }
                } else {
                    // An exclamation mark in place of the eyes.
                    NSBezierPath(roundedRect: NSRect(x: center.x - 0.75 * s, y: center.y + 2.4 * s, width: 1.5 * s, height: 3 * s),
                                 xRadius: 0.75 * s, yRadius: 0.75 * s).fill()
                    NSBezierPath(ovalIn: NSRect(x: center.x - 0.8 * s, y: center.y + 0.5 * s, width: 1.6 * s, height: 1.6 * s)).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Android"
        return image
    }
}
