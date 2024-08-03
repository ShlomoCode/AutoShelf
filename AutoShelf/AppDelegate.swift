import Cocoa
import SwiftUI

fileprivate func requestAccessibilityPermission (){
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
    if !AXIsProcessTrustedWithOptions(options) {
        print("AX Permission Not Granted!")
    } else {
        print("AX Permission Granted")
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var filesMonitor: DirectoryMonitor?
    private var dropshelfController: DropshelfController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application did finish launching")
        
        requestAccessibilityPermission()
        
        guard let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            let alert = NSAlert()
            alert.messageText = "Failed to locate Downloads directory. AutoShelf will quit."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSApplication.shared.terminate(nil)
            return
        }
        
        print("Starting Watching at \(downloadsPath.path)")
        
        filesMonitor = DirectoryMonitor(downloadsPath)
        filesMonitor!.startMonitoring()
        
        dropshelfController = DropshelfController.shared
    }
}
