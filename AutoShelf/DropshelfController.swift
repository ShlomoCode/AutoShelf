import Cocoa

struct ManagedShelf {
    var axElement: AXUIElement
    var addedDate = Date()
    var fileURL: URL
}

fileprivate func sendFileToDropshelfService(fileURLs: [URL]) -> Bool {
    let pasteboard = NSPasteboard.withUniqueName()
    
    let success = pasteboard.writeObjects(fileURLs as [NSURL])
    
    if success {
        NSPerformService("Send to Dropshelf", pasteboard)
        return true
    } else {
        return false
    }
}

fileprivate func windowsObserverCallback(observer: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) {
    DropshelfController.shared.managedShelves.removeAll { $0.axElement == element }
}

class DropshelfController: ObservableObject {
    var processIdentifier: pid_t
    var appAxElement: AXUIElement
    private var windowsObserver: AXObserver
    @Published var managedShelves: [ManagedShelf] = []
    static let shared = DropshelfController()
    
    private init() {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.pilotmoon.Dropshelf").first else {
            let alert = NSAlert()
            alert.messageText = "Can't find Dropshelf running process"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            fatalError("Dropshelf not running")
        }
        
        self.processIdentifier = app.processIdentifier
        self.appAxElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var observer: AXObserver?
        guard AXObserverCreate(app.processIdentifier, windowsObserverCallback, &observer) == .success else {
            fatalError("Failed to create AXObserver")
        }
        self.windowsObserver = observer!
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(),AXObserverGetRunLoopSource(windowsObserver),.defaultMode)
    }
    
    private func closeShelf(_ managedShelf: ManagedShelf) {
        var children: CFTypeRef?
        // The close button is the first child of the window
        guard AXUIElementCopyAttributeValue(managedShelf.axElement, kAXChildrenAttribute as CFString, &children) == .success,
              let closeButton = (children as? [AXUIElement])?.first else {
            print("Cannot locate the children")
            return
        }
        
        AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
        
        managedShelves.removeAll { $0.axElement == managedShelf.axElement }
    }
    
    func closeAllShelfs() {
        for managedShelf in managedShelves {
            closeShelf(managedShelf)
        }
    }
    
    func getOpenShelfs() -> [AXUIElement] {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(DropshelfController.shared.appAxElement, kAXWindowsAttribute as CFString, &value)
        
        guard result == .success, let windows = value as? [AXUIElement] else {
            return []
        }
        
        return windows.filter { window in
            var subroleValue: AnyObject?
            let subroleResult = AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleValue)
            
            return subroleResult == .success && (subroleValue as? String) == kAXSystemDialogSubrole as String
        }
    }
    
    func addFile(fileURL: URL) {
        let shelfWindowsBefore = getOpenShelfs()
        
        guard sendFileToDropshelfService(fileURLs: [fileURL]) else {
            print("Failed to send file to Dropshelf")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            let shelfWindowsAfter = self.getOpenShelfs()
            guard let newWindow = shelfWindowsAfter.first(where: { !shelfWindowsBefore.contains($0) }) else {
                print("Failed to find new shelf window")
                return
            }
            
            let newShelf = ManagedShelf(axElement: newWindow, fileURL: fileURL)
            DispatchQueue.main.async {
                self.managedShelves.append(newShelf)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self.closeShelf(newShelf)
                self.managedShelves.removeAll { $0.axElement == newShelf.axElement }
            }
            
            AXObserverAddNotification(self.windowsObserver, newWindow, kAXUIElementDestroyedNotification as CFString, nil)
        }
    }
}
