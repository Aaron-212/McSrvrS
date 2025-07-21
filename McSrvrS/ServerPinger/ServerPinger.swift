import Foundation
import SwiftData

protocol ServerPinger: AnyObject {
    func ping(host: String, port: UInt16) async -> Result<
        ServerStatus.StatusData, ServerPingerError
    >
}
