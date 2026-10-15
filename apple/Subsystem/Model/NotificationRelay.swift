// Mac Subsystem for Android - Android notifications as macOS notifications.
//
// The bridge app's NotificationListenerService keeps the active notifications;
// the Mac reads them (notifications.json) every few seconds, posts new ones with
// UserNotifications, and removes them when they go away on Android. Clicking one
// opens that Android app in its window.
//
// Licensed under the GNU General Public License v3 or later.

import Foundation
import UserNotifications

struct AndroidNotification: Codable, Hashable {
    let key: String
    let package: String
    let title: String
    let text: String
    let posted: Int64
    let ongoing: Bool?
}

@MainActor
final class NotificationRelay: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRelay()
    private var shown: [String: Int64] = [:]
    private var primed = false

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Called with the latest list from the bridge. The first list after boot only
    /// records what exists, so old notifications don't all pop up at once.
    func update(_ notifications: [AndroidNotification], apps: [AndroidApp]) {
        let center = UNUserNotificationCenter.current()
        let visible = notifications.filter { $0.ongoing != true && !($0.title.isEmpty && $0.text.isEmpty) }
        let current = Dictionary(visible.map { ($0.key, $0.posted) }, uniquingKeysWith: { a, _ in a })

        if primed {
            for notification in visible where shown[notification.key] != notification.posted {
                let content = UNMutableNotificationContent()
                let label = apps.first { $0.package == notification.package }?.label
                content.title = notification.title.isEmpty ? (label ?? notification.package) : notification.title
                if let label, !notification.title.isEmpty { content.subtitle = label }
                content.body = notification.text
                content.sound = .default
                content.threadIdentifier = notification.package
                content.userInfo = ["package": notification.package]
                let iconURL = SubsystemPaths.icon(for: notification.package)
                if FileManager.default.fileExists(atPath: iconURL.path) {
                    // Attachments are moved by the system, so attach a copy.
                    let copy = SubsystemPaths.notificationAttachments.appendingPathComponent("\(UUID().uuidString).png")
                    if (try? FileManager.default.copyItem(at: iconURL, to: copy)) != nil,
                       let attachment = try? UNNotificationAttachment(identifier: "icon", url: copy) {
                        content.attachments = [attachment]
                    }
                }
                center.add(UNNotificationRequest(identifier: notification.key, content: content, trigger: nil))
            }
            let gone = shown.keys.filter { current[$0] == nil }
            if !gone.isEmpty { center.removeDeliveredNotifications(withIdentifiers: gone) }
        }
        shown = current
        primed = true
    }

    func reset() {
        primed = false
        shown = [:]
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let package = response.notification.request.content.userInfo["package"] as? String
        Task { @MainActor in
            if let package { AppCatalog.open(package: package) }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
