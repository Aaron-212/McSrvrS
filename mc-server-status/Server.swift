import Foundation
import SwiftData

@Model
final class Server {
    // Calculated
    var id: UUID
    // User defined
    var name: String
    var domain: String
    var port: UInt16
    // Auto generated
    var state: State
    var lastSeenDate: Date
    var lastUpdatedDate: Date

    init(name: String, domain: String, port: UInt16 = 25565) {
        self.id = UUID()
        self.name = name
        self.domain = domain
        self.port = port
        self.state = .unknown
        self.lastSeenDate = Date.now
        self.lastUpdatedDate = Date.now
    }

    enum State {
        case online
        case offline
        case pinging
        case unknown
    }
}
