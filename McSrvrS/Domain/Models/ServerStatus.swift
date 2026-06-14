import Foundation
import SwiftData

@Model
final class ServerStatus {
    @Attribute(.unique)
    var id: UUID
    var server: Server?
    var timestamp: Date
    var state: StatusState

    init(server: Server, state: StatusState) {
        self.id = UUID()
        self.server = server
        self.timestamp = Date.now
        self.state = state
    }

    // MARK: - Status State

    enum StatusState: Codable {
        case loading
        case success(StatusData)
        case error(String)
    }

    // MARK: - Status Data (moved from Server.Status)

    struct StatusData: Codable {
        let version: Version
        let players: Players?
        let motd: String?
        let favicon: String?
        let latency: UInt64?
    }

    struct Version: Codable {
        let name: String
        let `protocol`: Int
    }

    struct Player: Codable {
        let id: UUID  // Generated UUID for uniqueness
        let name: String
        let playerId: String  // Original UUID from server

        var avatarUrl: URL? {
            if self.playerId == "00000000-0000-0000-0000-000000000000" {
                return nil  // No avatar for anonymous players
            } else {
                return URL(string: "https://crafatar.com/avatar/\(self.playerId)?size=64&overlay")
            }
        }

        init(name: String, playerId: String) {
            self.id = UUID()
            self.name = name
            self.playerId = playerId
        }
    }

    struct Players: Codable {
        let max: UInt32
        let online: UInt32
        let sample: [Player]?
    }

    // MARK: - Convenience Properties

    var isSuccess: Bool {
        if case .success = state { return true }
        return false
    }

    var isError: Bool {
        if case .error = state { return true }
        return false
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var statusData: StatusData? {
        if case .success(let data) = state { return data }
        return nil
    }

    var errorMessage: String? {
        if case .error(let message) = state { return message }
        return nil
    }
}
