import Foundation

extension Notification.Name {
    static let addNewServer = Notification.Name("addNewServer")
    static let refreshThisServer = Notification.Name("refreshThisServer")
    static let refreshAllServers = Notification.Name("refreshAllServers")
    static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")
}
