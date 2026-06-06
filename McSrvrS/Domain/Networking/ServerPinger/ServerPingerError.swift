import Foundation

enum ServerPingerError: Error, CustomStringConvertible {
    case connectionFailed(Error)
    case timedOut
    case dataError(String)
    case encodingError

    public var description: String {
        switch self {
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .timedOut:
            return "The ping operation timed out."
        case .dataError(let details):
            return "Data parsing error: \(details)"
        case .encodingError:
            return "Failed to encode data for ping operation."
        }
    }
}
