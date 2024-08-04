import SwiftUI
import Defaults
import Combine
import Settings

@main
struct AutoShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dropshelfController = DropshelfController.shared
    @Default(.showMenuBarIcon) var showMenuBarIcon
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
        
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            Text("Current Shelves (\(dropshelfController.managedShelves.count))")
            ForEach(dropshelfController.managedShelves, id: \.self.axElement) { download in
                Text(download.itemURL.lastPathComponent)
            }
            
            Button("Close All") {
                DropshelfController.shared.closeAll()
            }.disabled(dropshelfController.managedShelves.count == 0)
            
            Divider()
            
            Button(action: {
                appDelegate.settingsWindowController.openSettingsWindow()
            }) {
                Text("Settings")
            }
            
            Button("Quit AutoShelf") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
        } label: {
            // https://stackoverflow.com/a/77263538
            let image: NSImage = {
                let ratio = $0.size.height / $0.size.width
                $0.size.height = 19
                $0.size.width = 19 / ratio
                return $0
            }(NSImage(named: "MenuBarIcon")!)
            
            Image(nsImage: image)
        }
    }
}
