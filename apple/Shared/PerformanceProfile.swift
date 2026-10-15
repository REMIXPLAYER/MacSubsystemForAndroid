// Mac Subsystem for Android - performance modes.
//
//   Power Saver   Android only runs while an Android app is open (it turns off
//                 30 s after the last one closes; see Subsystem.idleShutdownDelay).
//                 While it runs it adapts like Smart, but never above Balanced:
//                 the Saver level unless an Android app is in front and the Mac
//                 has power and resources to spare.
//   Smart         Android stays ready in the background and adapts all the time:
//                 full speed for the app in front, Gaming for a game, and the
//                 Saver level as soon as other Mac apps need the processor or
//                 memory, the battery runs low, Low Power Mode is on or the Mac
//                 gets hot.
//   Performance   every core and all memory, always.
//   Gaming        Performance plus Android's fixed-performance and game modes,
//                 up to 120 fps and a higher-quality stream.
//
// Levels and what they change:
//   Saver         QEMU as a background task (efficiency cores, low I/O priority),
//                 2 cores online in Android, 60% memory (balloon), Android's
//                 battery saver, 30 fps windows.
//   Balanced      half the cores, 85% memory, 60 fps.
//   Performance   all cores and memory, normal priority, 60 fps.
//   Game          Performance + fixed-performance mode, 120 fps, higher bitrate.
//
// The Subsystem applies the level to the VM; app windows read it from
// status.json when they open (frame rate, bitrate, game tweaks).
//
// Licensed under the GNU General Public License v3 or later.

import Foundation

enum PerformanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case powerSaver
    case smart
    case performance
    case game

    var id: String { rawValue }

    var title: String {
        switch self {
        case .powerSaver: return "Power Saver"
        case .smart: return "Smart"
        case .performance: return "Performance"
        case .game: return "Gaming"
        }
    }

    var symbol: String {
        switch self {
        case .powerSaver: return "leaf"
        case .smart: return "wand.and.stars"
        case .performance: return "gauge.with.dots.needle.100percent"
        case .game: return "gamecontroller"
        }
    }

    var summary: String {
        switch self {
        case .powerSaver:
            return "Android only runs while an Android app is open, and adapts while it does: frugal by default, a little faster for the app in front when your Mac has power to spare."
        case .smart:
            return "Stays ready so apps open instantly, and adapts all the time: full speed for the app you're using, and power saving as soon as other apps need your Mac or the battery runs low."
        case .performance:
            return "Maximum performance: every processor core and all of Android's memory, all the time."
        case .game:
            return "Maximum performance tuned for games: Android's game optimizations, up to 120 fps and lower input latency."
        }
    }
}

/// What a mode means right now. Smart resolves to one of the others.
enum PerformanceLevel: String, Codable, Sendable {
    case saver
    case balanced
    case performance
    case game

    var title: String {
        switch self {
        case .saver: return "Saving power"
        case .balanced: return "Balanced"
        case .performance: return "Performance"
        case .game: return "Gaming"
        }
    }

    /// Share of the VM's processor cores kept online inside Android.
    var cpuShare: Double {
        switch self {
        case .saver: return 0.25
        case .balanced: return 0.5
        case .performance, .game: return 1
        }
    }

    /// Share of the VM's memory Android keeps; the rest goes back to macOS.
    var memoryShare: Double {
        switch self {
        case .saver: return 0.6
        case .balanced: return 0.85
        case .performance, .game: return 1
        }
    }

    /// QEMU runs as a background task (efficiency cores, throttled I/O).
    var backgroundPriority: Bool { self == .saver }
    var androidBatterySaver: Bool { self == .saver }
    var androidFixedPerformance: Bool { self == .game }

    var maxFPS: Int {
        switch self {
        case .saver: return 30
        case .balanced, .performance: return 60
        case .game: return 120
        }
    }

    var videoBitRate: Int {
        switch self {
        case .saver: return 6_000_000
        case .balanced: return 10_000_000
        case .performance: return 14_000_000
        case .game: return 20_000_000
        }
    }
}
