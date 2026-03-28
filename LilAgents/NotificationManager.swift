import Foundation
import UserNotifications

class NotificationManager: NSObject {
    static let shared = NotificationManager()
    private var authorized = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            DispatchQueue.main.async { self.authorized = granted }
        }
    }

    func sendCompletion(characterName: String) {
        guard authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = characterName
        content.body = "回复完成"
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner])
    }
}
