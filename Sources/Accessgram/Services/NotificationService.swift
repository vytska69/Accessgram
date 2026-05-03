import UserNotifications
import AppKit

final class NotificationService: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationService()
    static let openChatNotification = Notification.Name("AccessgramOpenChat")

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Send

    func send(chatId: Int64, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body.isEmpty ? " " : body
        content.sound = .default
        content.userInfo = ["chat_id": chatId]

        let request = UNNotificationRequest(
            identifier: "msg-\(chatId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Show in foreground (needed so delegate is called even when app is active)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Only show banner when app is not the key window for that chat
        completionHandler([.banner, .sound])
    }

    // MARK: - Tap handling

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let chatId = response.notification.request.content.userInfo["chat_id"] as? Int64 {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.openChatNotification,
                    object: nil,
                    userInfo: ["chat_id": chatId]
                )
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        completionHandler()
    }
}
