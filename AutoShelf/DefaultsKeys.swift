import Cocoa
import Defaults

extension Defaults.Keys {
    static let showMenuBarIcon = Key<Bool>("showMenuBarIcon", default: true)
    static let isNotificationsEnabled = Key<Bool>("isNotificationsEnabled", default: false)
    static let autoCloseShelfDurationInSeconds = Key<Double>("autoCloseShelfDurationInSeconds", default: 30)
    static let monitoredPath = Key<URL>("monitoredPath", default: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!)
}
