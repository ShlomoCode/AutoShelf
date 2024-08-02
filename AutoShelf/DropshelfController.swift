import Cocoa

class DropshelfController {
    static func sendToDropshelf(filePaths: [String]) -> Void {
        let pasteboard = NSPasteboard.withUniqueName()
        
        let fileURLs = filePaths.compactMap { URL(fileURLWithPath: $0) }
        pasteboard.writeObjects(fileURLs as [NSURL])
        
        NSPerformService("Send to Dropshelf", pasteboard)
    }
}
