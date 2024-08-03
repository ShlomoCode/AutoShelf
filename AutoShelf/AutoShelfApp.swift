import SwiftUI

@main
struct AutoShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dropshelfController = DropshelfController.shared
    
    var body: some Scene {
        MenuBarExtra("main", systemImage: "tray.and.arrow.down.fill") {
            Text("Auto Shelf")
            
            Divider()
            
            Text("Current Shelfs (\(dropshelfController.managedShelves.count))")
            ForEach(dropshelfController.managedShelves, id: \.self.axElement) { download in
                Text(download.fileURL.lastPathComponent)
            }
            
            Button("Close All") {
                DropshelfController.shared.closeAllShelfs()
            }.disabled(dropshelfController.managedShelves.count == 0)
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
        }
    }
}
