import Foundation

protocol ServerPinger {
    func ping(address: String) async -> Result<
        ServerStatus.StatusData, ServerPingerError
    >
}
