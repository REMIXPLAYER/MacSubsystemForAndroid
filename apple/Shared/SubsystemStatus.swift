// Mac Android Subsystem - the status file the Subsystem app keeps up to date.
//
// Launchers are separate processes (one per Android app, so each gets its own
// Dock icon), so they learn whether Android is up from this file rather than IPC.
// The Subsystem app is the only writer.
//
// Licensed under the GNU General Public License v3 or later.

import Foundation

struct SubsystemStatus: Codable, Equatable, Sendable {
    enum State: String, Codable, Sendable {
        /// No Android image installed yet.
        case notInstalled
        case off
        case starting
        /// Android has booted and the bridge is installed: apps can open.
        case running
        case stopping
        case failed
    }

    var state: State
    var message: String?
    var adbPort: UInt16
    var androidVersion: String?
    /// Process id of the Subsystem app, so a stale file is recognisable.
    var pid: Int32
    var updated: Date
    /// The chosen mode and what it currently means (see PerformanceProfile.swift).
    var mode: PerformanceMode?
    var level: PerformanceLevel?

    static func read() -> SubsystemStatus? {
        guard let data = try? Data(contentsOf: SubsystemPaths.status) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let status = try? decoder.decode(SubsystemStatus.self, from: data) else { return nil }
        // A crashed Subsystem app leaves its last state behind.
        if kill(status.pid, 0) != 0 && errno == ESRCH {
            var stale = status
            stale.state = .off
            return stale
        }
        return status
    }

    func write() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: SubsystemPaths.status, options: .atomic)
    }
}
