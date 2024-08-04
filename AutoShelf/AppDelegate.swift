import Cocoa
import SwiftUI
import Settings
import Defaults
import Combine

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
    lazy var settingsWindowController = SettingsWindowManager.shared
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Application did finish launching")
        NSApplication.shared.setActivationPolicy(.accessory)
        
        requestAccessibilityPermission()
        
        dropshelfController = DropshelfController.shared
        
        self.setupMonitored(path: Defaults[.monitoredPath])
        Task {
            for await newPath in Defaults.updates(.monitoredPath) {
                if newPath != filesMonitor?.watchDirURL { // Prevent initial value trigger
                    self.setupMonitored(path: newPath)
                }
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindowController.openSettingsWindow()
        return false
    }
    
    
    private func setupMonitored(path: URL) {
        filesMonitor?.stopMonitoring()
        filesMonitor = DirectoryMonitor(path)
        filesMonitor?.startMonitoring()
        print("Starting Watching at \(path)")
    }
}
