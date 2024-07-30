import Cocoa
import UserNotifications
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var downloadMonitor: DownloadMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application did finish launching")
        requestNotificationPermission()
        startDownloadMonitoring()
    }
    
    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert]) { granted, error in
            guard granted else {
                self.showNotificationPermissionError(error)
                return
            }
            print("Notification permission granted")
        }
    }
    
    private func showNotificationPermissionError(_ error: Error?) {
        let alert = NSAlert()
        alert.messageText = "Failed to request notification authorization: \(error?.localizedDescription ?? "Unknown error")"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func startDownloadMonitoring() {
        guard let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            let alert = NSAlert()
            alert.messageText = "Failed to locate Downloads directory. Auto Shelf will quit."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSApplication.shared.terminate(nil)
            return
        }
        
        print("Downloads directory: \(downloadsPath.path)")
        self.downloadMonitor = DownloadMonitor(downloadsURL: downloadsPath)
        self.downloadMonitor?.startMonitoring()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

@available(macOS 14.5, *)
class DownloadMonitor: NSObject {
    private let downloadsURL: URL
    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default
    private var knownFiles: Set<String> = []
    
    init(downloadsURL: URL) {
        self.downloadsURL = downloadsURL
        super.init()
        self.knownFiles = Set(try! fileManager.contentsOfDirectory(atPath: downloadsURL.path))
    }
    
    func startMonitoring() {
        let monitorQueue = DispatchQueue(label: "com.AutoShelf.FSEventStream", qos: .utility)
        
        monitorQueue.async {
            NSFileCoordinator().coordinate(
                readingItemAt: self.downloadsURL,
                options: [.immediatelyAvailableMetadataOnly],
                error: nil
            ) { newURL in
                NSFileCoordinator.addFilePresenter(self)
                
                let fileSystemMonitor = AsyncStream<[URL]> { continuation in
                    self.monitorDownloadsDirectory(continuation: continuation)
                }
                
                Task {
                    for try await changes in fileSystemMonitor {
                        for change in changes {
                            // Skip files that do not have a default application, as they are likely temporary files
                            guard hasDefaultApplicationForFile(fileName: change.lastPathComponent) else {
                                continue
                            }
                            
                            if self.fileManager.fileExists(atPath: change.path) {
                                self.notifyFileAdded(change.lastPathComponent)
                            } else {
                                self.notifyFileDeleted(change.lastPathComponent)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func monitorDownloadsDirectory(continuation: AsyncStream<[URL]>.Continuation) {
        let descriptor = open(self.downloadsURL.path, O_EVTONLY)
        guard descriptor != -1 else {
            print("Failed to open file descriptor: \(String(cString: strerror(errno)))")
            continuation.finish()
            return
        }
        
        let eventStream = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .all,
            queue: DispatchQueue.global()
        )
        
        eventStream.setEventHandler {
            let currentDownloadedFiles = Set(
                (try? self.fileManager.contentsOfDirectory(atPath: self.downloadsURL.path)) ?? []
            )
            let changes = self.detectChanges(currentFiles: currentDownloadedFiles)
            continuation.yield(changes)
            self.knownFiles = currentDownloadedFiles
        }
        
        eventStream.setCancelHandler {
            close(descriptor)
            continuation.finish()
        }
        
        eventStream.resume()
        
        continuation.onTermination = { _ in
            eventStream.cancel()
        }
    }
    
    private func detectChanges(currentFiles: Set<String>) -> [URL] {
        let addedFiles = currentFiles.subtracting(knownFiles)
        let deletedFiles = knownFiles.subtracting(currentFiles)
        return (addedFiles.union(deletedFiles)).map { self.downloadsURL.appendingPathComponent($0) }
    }
    
    private func notifyFileAdded(_ fileName: String) {
        let content = createNotificationContent(
            title: "New Download",
            body: "File '\(fileName)' has been added to Downloads"
        )
        scheduleNotification(content: content)
    }
    
    private func notifyFileDeleted(_ fileName: String) {
        let content = createNotificationContent(
            title: "File Deleted",
            body: "File '\(fileName)' has been removed from Downloads"
        )
        scheduleNotification(content: content)
    }
    
    private func createNotificationContent(title: String, body: String) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }
    
    private func scheduleNotification(content: UNNotificationContent) {
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
}

extension DownloadMonitor: NSFilePresenter {
    var presentedItemURL: URL? {
        return downloadsURL
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return .main
    }
    
    func presentedItemDidChange() {
        // This method is called when changes occur to the presented directory
        // We're handling changes in our file system monitor, so we don't need to do anything here
    }
}
