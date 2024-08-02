import Cocoa
import UserNotifications
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var filesMonitor: DirectoryMonitor?
    
    override init() {
        super.init()
        
        guard let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            let alert = NSAlert()
            alert.messageText = "Failed to locate Downloads directory. AutoShelf will quit."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSApplication.shared.terminate(nil)
            return
        }
        
        print("Watching directory: \(downloadsPath.path)")
        self.filesMonitor = DirectoryMonitor(downloadsPath)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application did finish launching")
        
        Notifications.requestNotificationPermission()
        
        self.filesMonitor?.startMonitoring()
    }
}
