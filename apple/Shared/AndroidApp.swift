// Mac Android Subsystem - an app installed in Android, as reported by the bridge app.
// Licensed under the GNU General Public License v3 or later.

import Foundation

struct AndroidApp: Codable, Hashable, Identifiable, Sendable {
    /// Package name, e.g. org.fdroid.fdroid
    let package: String
    /// Launcher activity as a short component name, e.g. org.fdroid.fdroid/.views.main.MainActivity
    var activity: String
    var label: String
    var versionName: String
    var isSystem: Bool
    /// The icon is an adaptive icon rendered edge to edge (no mask).
    var adaptiveIcon: Bool
    /// PackageInfo.lastUpdateTime; changes when the app is updated, so launchers refresh.
    var updated: Int64
    /// The app says it's a game (Smart mode switches to the Game level when it's in front).
    var isGame: Bool

    var id: String { package }

    enum CodingKeys: String, CodingKey {
        case package, activity, label, versionName, isSystem = "system", adaptiveIcon = "adaptive", updated, isGame = "game"
    }

    init(package: String, activity: String, label: String, versionName: String = "",
         isSystem: Bool = false, adaptiveIcon: Bool = false, updated: Int64 = 0, isGame: Bool = false) {
        self.package = package
        self.activity = activity
        self.label = label
        self.versionName = versionName
        self.isSystem = isSystem
        self.adaptiveIcon = adaptiveIcon
        self.updated = updated
        self.isGame = isGame
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        package = try c.decode(String.self, forKey: .package)
        activity = try c.decodeIfPresent(String.self, forKey: .activity) ?? package
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? package
        versionName = try c.decodeIfPresent(String.self, forKey: .versionName) ?? ""
        isSystem = try c.decodeIfPresent(Bool.self, forKey: .isSystem) ?? false
        adaptiveIcon = try c.decodeIfPresent(Bool.self, forKey: .adaptiveIcon) ?? false
        updated = try c.decodeIfPresent(Int64.self, forKey: .updated) ?? 0
        isGame = try c.decodeIfPresent(Bool.self, forKey: .isGame) ?? false
    }

    /// A launcher bundle identifier made from the package name.
    var launcherBundleID: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        let safe = String(package.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        return "\(AppConfig.launcherBundlePrefix).\(safe)"
    }

    /// File-system safe name for ~/Applications/Android Apps/<name>.app
    var launcherFileName: String {
        let cleaned = label.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? package : cleaned
    }
}

enum AppStore {
    static func load() -> [AndroidApp] {
        guard let data = try? Data(contentsOf: SubsystemPaths.apps) else { return [] }
        return (try? JSONDecoder().decode([AndroidApp].self, from: data)) ?? []
    }

    static func save(_ apps: [AndroidApp]) {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        try? data.write(to: SubsystemPaths.apps, options: .atomic)
    }
}
