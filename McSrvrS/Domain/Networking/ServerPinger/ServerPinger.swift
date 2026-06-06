import Foundation

protocol ServerPinger: AnyObject {
    func ping(address: String) async -> Result<
        ServerStatus.StatusData, ServerPingerError
    >
}
