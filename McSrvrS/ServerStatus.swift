import Foundation
import SwiftData

@Model
final class ServerStatus {
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

        // Variable Color for SF Symbol
        public var latencyVariableColor: Double {
            guard let latency = latency else { return 0.0 }
            switch latency {
            case 0..<50:
                return 1.0
            case 50..<100:
                return 0.75
            case 100..<200:
                return 0.5
            case 200..<300:
                return 0.25
            default:
                return 0.0
            }
        }
    }

    struct Version: Codable {
        let name: String
    }

    struct Player: Codable {
        let id: UUID  // Generated UUID for uniqueness
        let name: String
        let playerId: String  // Original UUID from server

        var avatarUrl: URL? {
            if self.playerId == "00000000-0000-0000-0000-000000000000" {
                return nil  // No avatar for anonymous players
            } else {
                return URL(string: "https://mc-heads.net/avatar/\(self.playerId)")
            }
        }

        init(name: String, playerId: String) {
            self.id = UUID()
            self.name = name
            self.playerId = playerId
        }

        enum CodingKeys: String, CodingKey {
            case name
            case playerId = "id"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.name = try container.decode(String.self, forKey: .name)
            self.playerId = try container.decode(String.self, forKey: .playerId)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(playerId, forKey: .playerId)
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
