import UserNotifications
import SwiftUI

class Notifications {
    static func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let permissionGranted = try? await center.requestAuthorization(options: [.alert])
        if let permissionGranted = permissionGranted, permissionGranted == true {
            print("Notification permission granted")
        } else {
            print("Notification permission not granted")
        }
    }
    
    static func notifyItemAdded(itemPath: URL, itemType: FileAttributeType) {
        let itemTypeReadableName = itemType == .typeDirectory ? "Directory" : "File"
        let parentDir = itemPath.deletingLastPathComponent().lastPathComponent
        let content = createNotificationContent(
            title: "New \(itemTypeReadableName) in Downloads",
            body: "The \(itemTypeReadableName) '\(itemPath.lastPathComponent)' has been added to \(parentDir)"
        )
        scheduleNotification(content: content)
    }
    
    static func notifyItemDeleted(itemPath: URL, itemType: FileAttributeType) {
        let itemTypeReadableName = itemType == .typeDirectory ? "Directory" : "File"
        let parentDir = itemPath.deletingLastPathComponent().lastPathComponent
        let content = createNotificationContent(
            title: "\(itemTypeReadableName) Deleted from Downloads",
            body: "The \(itemTypeReadableName) '\(itemPath.lastPathComponent)' has been removed from \(parentDir)"
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
