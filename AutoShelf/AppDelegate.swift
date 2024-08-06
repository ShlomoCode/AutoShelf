import Cocoa
import SwiftUI
import Settings
import Defaults
import Combine
import os

fileprivate func requestAccessibilityPermission (){
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
    if !AXIsProcessTrustedWithOptions(options) {
        logger.log("AX Permission Not Granted!")
    } else {
        logger.log("AX Permission Granted")
    }
}

let logger = Logger(subsystem: "main", category: "network")

class AppDelegate: NSObject, NSApplicationDelegate {
    private var filesMonitor: DirectoryMonitor?
    private var dropshelfController: DropshelfController?
    lazy var settingsWindowController = SettingsWindowManager.shared
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.log("Application did finish launching")
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
        logger.log("Starting Watching at \(path)")
    }
}
