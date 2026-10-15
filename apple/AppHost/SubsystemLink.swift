// Mac Android Subsystem - how an app window gets Android running.
//
// It opens the Subsystem app with msa://start (which boots Android if it is off,
// and shows "Starting Android…" meanwhile), then waits for
// status.json to say Android is running.
//
// Licensed under the GNU General Public License v3 or later.

import AppKit

enum SubsystemLink {
    enum Failure: LocalizedError {
        case subsystemMissing
        case notInstalled
        case failed(String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .subsystemMissing: return "\(AppConfig.displayName) isn't installed. Reinstall it, then open this app again."
            case .notInstalled: return "Android isn't set up yet. Open \(AppConfig.displayName) to finish setting it up."
            case .failed(let message): return message
            case .timeout: return "Android took too long to start. Open \(AppConfig.displayName) to see what happened."
            }
        }
    }

    static var subsystemAppURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: AppConfig.subsystemBundleID)
    }

    /// The scrcpy server bundled with the Subsystem app.
    static var scrcpyServerURL: URL? {
        subsystemAppURL?.appendingPathComponent("Contents/Resources/scrcpy-server.jar")
    }

    /// Ask the Subsystem to start Android (and open package afterwards in its own bookkeeping).
    static func requestStart(package: String) {
        var components = URLComponents()
        components.scheme = AppConfig.urlScheme
        components.host = "start"
        components.queryItems = [URLQueryItem(name: "package", value: package)]
        guard let url = components.url else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        if let app = subsystemAppURL {
            NSWorkspace.shared.open([url], withApplicationAt: app, configuration: configuration)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Wait until Android is running. `progress` gets status messages for the splash screen.
    static func waitUntilRunning(package: String, timeout: TimeInterval = 240,
                                 progress: @escaping @MainActor (String) -> Void) async throws -> SubsystemStatus {
        guard subsystemAppURL != nil else { throw Failure.subsystemMissing }
        if let status = SubsystemStatus.read(), status.state == .running { return status }

        requestStart(package: package)
        let deadline = Date().addingTimeInterval(timeout)
        var lastRequest = Date()
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(400))
            guard let status = SubsystemStatus.read() else { continue }
            switch status.state {
            case .running:
                return status
            case .notInstalled:
                throw Failure.notInstalled
            case .failed:
                throw Failure.failed(status.message ?? "Android stopped.")
            case .starting, .stopping:
                await progress(status.message ?? "Starting Android…")
            case .off:
                // The Subsystem may still be launching; ask again now and then.
                if Date().timeIntervalSince(lastRequest) > 5 {
                    requestStart(package: package)
                    lastRequest = Date()
                }
            }
        }
        throw Failure.timeout
    }
}
