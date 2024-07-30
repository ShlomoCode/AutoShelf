import Foundation
import UniformTypeIdentifiers

func hasDefaultApplicationForFile(fileName: String) -> Bool {
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
