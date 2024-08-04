import SwiftUI
import Settings

class SettingsWindowControllerDelegate: NSObject, NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular) // Show dock icon on open settings window
    }
    
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Hide dock icon back
    }
}

class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    
    private lazy var settingsWindowController = SettingsWindowController(
        panes: [
            Settings.Pane(
                identifier: Settings.PaneIdentifier(rawValue: "general"),
                title: "General",
                toolbarIcon: NSImage()
            ) {
                SettingsView()
            }
        ],
        hidesToolbarForSingleItem: true
    )
    
    private let settingsWindowControllerDelegate = SettingsWindowControllerDelegate()
    
    private init() {
        setupSettingsWindowDelegate()
    }
    
    private func setupSettingsWindowDelegate() {
        settingsWindowController.window?.delegate = settingsWindowControllerDelegate
    }
    
    func openSettingsWindow() {
        settingsWindowController.show()
    }
}
