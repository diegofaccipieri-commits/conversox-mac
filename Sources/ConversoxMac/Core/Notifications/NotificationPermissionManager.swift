import Foundation
import UserNotifications

@MainActor
enum NotificationPermissionManager {
    static let shared = NotificationPermissionManagerImpl()
}

@MainActor
final class NotificationPermissionManagerImpl {
    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func notifyNewMessage(chatTitle: String, preview: String) {
        let content = UNMutableNotificationContent()
        content.title = chatTitle
        content.body = preview
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
