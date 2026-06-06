import Foundation

enum ServerPingerError: Error, CustomStringConvertible {
    case connectionFailed(Error)
    case cancelled
    case timedOut
    case dataError(String)
    case encodingError

    public var description: String {
        switch self {
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .cancelled:
            return "The ping operation was cancelled."
        case .timedOut:
            return "The ping operation timed out."
        case .dataError(let details):
            return "Data parsing error: \(details)"
        case .encodingError:
            return "Failed to encode data for ping operation."
        }
    }
}
