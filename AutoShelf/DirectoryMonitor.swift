import Cocoa
import UniformTypeIdentifiers
import Combine
import Defaults

fileprivate func hasDefaultApplicationForFile(fileName: String) -> Bool {
    let fileURL = URL(fileURLWithPath: fileName)
    let fileExtension = fileURL.pathExtension
    
    guard let uti = UTType(filenameExtension: fileExtension)?.identifier as CFString? else {
        return false
    }
    
    guard let _ = LSCopyDefaultApplicationURLForContentType(uti, .all, nil)?.takeRetainedValue() else {
        return false
    }
    
    return true
}

fileprivate func isHiddenDir(dirName: String) -> Bool {
    return dirName.hasPrefix(".")
}

class DirectoryMonitor: NSObject {
    var watchDirURL: URL
    private var knownItems: Set<String> = []
    private var eventStream: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    
    init(_ watchDirURL: URL) {
        self.watchDirURL = watchDirURL
        super.init()
    }
    
    func startMonitoring() {
        self.knownItems = Set(try! FileManager.default.contentsOfDirectory(atPath: watchDirURL.path))
        
        let monitorQueue = DispatchQueue(label: "com.AutoShelf.FSEventStream", qos: .utility)
        
        monitorQueue.async {
            NSFileCoordinator().coordinate(
                readingItemAt: self.watchDirURL,
                options: [.immediatelyAvailableMetadataOnly, .withoutChanges],
                error: nil
            ) { newURL in
                let fileSystemMonitor = AsyncStream<[URL]> { continuation in
                    self.monitorDirectory(continuation: continuation)
                }
                
                Task {
                    for try await changes in fileSystemMonitor {
                        for change in changes {
                            logger.log("Change detected, File: \(change.lastPathComponent)")
                            let itemType = (try? FileManager.default.attributesOfItem(atPath: change.path)[.type] as? FileAttributeType) ?? .typeUnknown
                            let isDir = itemType == .typeDirectory
                            if (isDir && !isHiddenDir(dirName: change.lastPathComponent)) || hasDefaultApplicationForFile(fileName: change.lastPathComponent) {
                                if FileManager.default.fileExists(atPath: change.path) {
                                    DropshelfController.shared.addItem(path: change)
                                    
                                    if Defaults[.isNotificationsEnabled] {
                                        Notifications.notifyItemAdded(itemPath: change, itemType: itemType)
                                    }
                                } else {
                                    if Defaults[.isNotificationsEnabled] {
                                        Notifications.notifyItemDeleted(itemPath: change, itemType: itemType)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func stopMonitoring() {
        eventStream?.cancel()
        eventStream = nil
        if descriptor != -1 {
            close(descriptor)
            descriptor = -1
        }
    }
    
    private func monitorDirectory(continuation: AsyncStream<[URL]>.Continuation) {
        descriptor = open(self.watchDirURL.path, O_EVTONLY)
        guard descriptor != -1 else {
            logger.log("Failed to open file descriptor: \(String(cString: strerror(errno)))")
            continuation.finish()
            return
        }
        
        eventStream = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .all,
            queue: DispatchQueue.global()
        )
        
        eventStream?.setEventHandler {
            let currentFiles = Set(
                (try? FileManager.default.contentsOfDirectory(atPath: self.watchDirURL.path)) ?? []
            )
            let changes = self.detectChanges(currentFiles: currentFiles)
            continuation.yield(changes)
            self.knownItems = currentFiles
        }
        
        eventStream?.setCancelHandler {
            close(self.descriptor)
            continuation.finish()
        }
        
        eventStream?.resume()
        
        continuation.onTermination = { [weak self] _ in
            self?.eventStream?.cancel()
        }
    }
    
    private func detectChanges(currentFiles: Set<String>) -> [URL] {
        let addedFiles = currentFiles.subtracting(knownItems)
        let deletedFiles = knownItems.subtracting(currentFiles)
        return (addedFiles.union(deletedFiles)).map { self.watchDirURL.appendingPathComponent($0) }
    }
}
