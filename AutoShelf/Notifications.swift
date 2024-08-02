import UserNotifications
import SwiftUI

class Notifications {
    static func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, error in
            guard granted else {
                let alert = NSAlert()
                alert.messageText = "Failed to request notification authorization: \(error?.localizedDescription ?? "Unknown error")"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }
            print("Notification permission granted")
        }
    }
    
    static func notifyFileAdded(fileName: String) {
        let content = createNotificationContent(
            title: "New Download",
            body: "File '\(fileName)' has been added to Downloads"
        )
        scheduleNotification(content: content)
    }
    
    static func notifyFileDeleted(fileName: String) {
        let content = createNotificationContent(
            title: "File Deleted",
            body: "File '\(fileName)' has been removed from Downloads"
        )
        scheduleNotification(content: content)
    }
    
    private static func createNotificationContent(title: String, body: String) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .none
        return content
    }
    
    private static func scheduleNotification(content: UNNotificationContent) {
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
}
