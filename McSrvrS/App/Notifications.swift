import Foundation

extension Notification.Name {
    static let addNewServer = Notification.Name("addNewServer")
    static let refreshThisServer = Notification.Name("refreshThisServer")
    static let refreshAllServers = Notification.Name("refreshAllServers")
    static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")
}

nonisolated enum AppStorageKey {
    static let foregroundRefreshInterval = "foregroundRefreshInterval"
    static let backgroundRefreshInterval = "backgroundRefreshInterval"
    static let showsMenuBarExtra = "showsMenuBarExtra"
}
