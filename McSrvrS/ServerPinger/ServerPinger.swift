import Foundation

protocol ServerPinger: AnyObject {
    func ping(host: String, port: UInt16) async -> Result<(String, Int), ServerPingerError>
}
