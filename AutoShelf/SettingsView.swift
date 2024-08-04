import SwiftUI
import Defaults
import LaunchAtLogin

struct SettingsView: View {
    @Default(.autoCloseShelfDurationInSeconds) var autoCloseShelfDurationInSeconds
    @Default(.isNotificationsEnabled) var isNotificationsEnabled
    @Default(.showMenuBarIcon) var showMenuBarIcon
    @Default(.monitoredPath) var monitoredPath
    
    @State private var isShowingFolderPicker = false
    @State private var hasAccessibilityPermission = false
    @State private var permissionCheckTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AccessibilityPermissionStatus(hasPermission: $hasAccessibilityPermission)
            MenuBarIconToggle(showMenuBarIcon: $showMenuBarIcon)
            LaunchAtLoginToggle()
            NotificationsToggle(isEnabled: $isNotificationsEnabled)
            AutoCloseDurationSlider(duration: $autoCloseShelfDurationInSeconds)
            MonitoredFolderPicker(monitoredPath: $monitoredPath, isShowingFolderPicker: $isShowingFolderPicker)
            QuitButton()
        }
        .padding(30)
        .frame(width: 500, height: 285)
        .fileImporter(isPresented: $isShowingFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let selectedURL = urls.first {
                monitoredPath = selectedURL
            }
        }
        .onAppear {
            hasAccessibilityPermission = AXIsProcessTrusted()
            
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                hasAccessibilityPermission = AXIsProcessTrusted()
            }
        }
        .onDisappear {
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
        }
    }
}

struct AccessibilityPermissionStatus: View {
    @Binding var hasPermission: Bool
    
    var body: some View {
        HStack {
            HStack (spacing: 2) {
                if hasPermission {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Accessibility Permission Granted")
                } else {
                    Image(systemName: "xmark.circle.fill")
                    Text("Accessibility Permission Not Granted")
                }
            }
            .foregroundColor(hasPermission ? .green : .red)
            .bold()
            
            Button("Settings") {
                openAccessibilitySettings()
            }
        }
    }
    
    private func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

struct MenuBarIconToggle: View {
    @Binding var showMenuBarIcon: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            if !showMenuBarIcon {
                Text("To open settings when the menu bar icon is hidden, relaunch the app.")
                    .foregroundColor(.gray)
                    .font(.footnote)
            }
        }
    }
}

struct LaunchAtLoginToggle: View {
    var body: some View {
        LaunchAtLogin.Toggle("Launch at login")
    }
}

struct NotificationsToggle: View {
    @Binding var isEnabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Enable notifications", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, isOn in
                    if isOn {
                        Task {
                            await Notifications.requestNotificationPermission()
                        }
                    }
                }
            Text("Shows notification for every created/deleted file.")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct AutoCloseDurationSlider: View {
    @Binding var duration: Double
    
    var body: some View {
        HStack {
            Text("Auto close duration:")
                .layoutPriority(1)
            Spacer()
            Slider(value: $duration, in: 5...120, step: 5)
            TextField("", value: $duration, formatter: NumberFormatter())
                .frame(width: 41)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Text("seconds")
        }
    }
}

struct MonitoredFolderPicker: View {
    @Binding var monitoredPath: URL
    @Binding var isShowingFolderPicker: Bool
    
    let commonFolders = [
        ("Downloads", FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!),
        ("Documents", FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!),
        ("Desktop", FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!)
    ]
    
    var body: some View {
        HStack {
            Text("Monitored Folder:")
            
            Button(action: {
                NSWorkspace.shared.open(monitoredPath)
            }) {
                Text(monitoredPath.lastPathComponent)
                    .truncationMode(.middle)
                    .lineLimit(1)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray)
                            .offset(y: 1),
                        alignment: .bottom
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { isHovered in
                if isHovered {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .help(monitoredPath.path)
            
            Menu("Choose Folder") {
                ForEach(commonFolders, id: \.0) { folderName, folderURL in
                    Button(folderName) {
                        monitoredPath = folderURL
                    }
                }
                Divider()
                Button("Choose Custom Folder...") {
                    isShowingFolderPicker = true
                }
            }
        }
    }
}

struct QuitButton: View {
    var body: some View {
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
