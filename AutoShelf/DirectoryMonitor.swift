import Cocoa
import UniformTypeIdentifiers
import Combine

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

class DirectoryMonitor: NSObject {
    private let watchDirURL: URL
    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default
    private var knownFiles: Set<String> = []
    
    init(_ watchDirURL: URL) {
        self.watchDirURL = watchDirURL
        super.init()
    }
    
    func startMonitoring() {
        self.knownFiles = Set(try! fileManager.contentsOfDirectory(atPath: watchDirURL.path))
        
        let monitorQueue = DispatchQueue(label: "com.AutoShelf.FSEventStream", qos: .utility)
        
        monitorQueue.async {
            NSFileCoordinator().coordinate(
                readingItemAt: self.watchDirURL,
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
                                DropshelfController.shared.addFile(fileURL: change)
                                
                                Notifications.notifyFileAdded(fileName: change.lastPathComponent)
                            } else {
                                Notifications.notifyFileDeleted(fileName: change.lastPathComponent)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func monitorDownloadsDirectory(continuation: AsyncStream<[URL]>.Continuation) {
        let descriptor = open(self.watchDirURL.path, O_EVTONLY)
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
                (try? self.fileManager.contentsOfDirectory(atPath: self.watchDirURL.path)) ?? []
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
        return (addedFiles.union(deletedFiles)).map { self.watchDirURL.appendingPathComponent($0) }
    }
}

extension DirectoryMonitor: NSFilePresenter {
    var presentedItemURL: URL? {
        return watchDirURL
    }
    
    var presentedItemOperationQueue: OperationQueue {
        return .main
    }
    
    func presentedItemDidChange() {
        // This method is called when changes occur to the presented directory
        // We're handling changes in our file system monitor, so we don't need to do anything here
    }
}
