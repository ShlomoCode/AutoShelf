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
        
        MenuBarExtra("main", systemImage: "tray.and.arrow.down.fill", isInserted: $showMenuBarIcon) {
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
        }
    }
}
