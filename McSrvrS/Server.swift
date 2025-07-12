import Foundation
import Network
import SwiftData

@Model
final class Server {
    // Calculated
    var id: UUID
    // User defined
    var name: String
    var host: String
    var port: UInt16
    // Auto generated
    var serverState: ServerState
    var lastSeenDate: Date?
    var lastUpdatedDate: Date

    init(name: String, host: String, port: UInt16 = 25565) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.serverState = .loading
        self.lastUpdatedDate = Date.now
    }

    // MARK: - Internal Data Structures (SwiftData)

    struct Version: Codable {
        let name: String
    }

    struct Player: Codable {
        let id: UUID // Generated UUID for uniqueness
        let name: String
        let playerId: String // Original UUID from server

        var avatarUrl: URL? {
            return URL(string: "https://mc-heads.net/avatar/\(self.playerId)")
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

    struct Status: Codable {
        let version: Version
        let players: Players
        let motd: String
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

        public var latencyDescription: String {
            guard let latency = latency else { return "Unknown Ping" }
            return "\(latency) ms"
        }

        public var playersDescription: String {
            return "\(players.online) / \(players.max)"
        }
    }

    // MARK: - External DTO (JSON Parsing)

    private struct StatusDto: Codable {
        let version: Version
        let players: Players
        let motd: String
        let favicon: String?

        enum CodingKeys: String, CodingKey {
            case version, players, favicon
            case motd = "description"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            version = try container.decode(Version.self, forKey: .version)
            players = try container.decode(Players.self, forKey: .players)
            favicon = try container.decodeIfPresent(String.self, forKey: .favicon)

            // Handle motd which can be either string or object with text field
            if let motdString = try? container.decode(String.self, forKey: .motd) {
                motd = motdString
            } else if let motdObject = try? container.decode([String: String].self, forKey: .motd),
                let text = motdObject["text"]
            {
                motd = text
            } else {
                motd = ""
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(version, forKey: .version)
            try container.encode(players, forKey: .players)
            try container.encode(motd, forKey: .motd)
            try container.encodeIfPresent(favicon, forKey: .favicon)
        }

        func toStatus(latency: UInt64?) -> Status {
            return Status(
                version: version,
                players: players,
                motd: motd,
                favicon: favicon,
                latency: latency
            )
        }

        static func parse(_ jsonString: String) -> Result<StatusDto, Error> {
            guard let data = jsonString.data(using: .utf8) else {
                return .failure(NSError(domain: "InvalidString", code: 1, userInfo: nil))
            }

            do {
                let dto = try JSONDecoder().decode(StatusDto.self, from: data)
                return .success(dto)
            } catch {
                return .failure(error)
            }
        }
    }

    enum ServerState: Codable {
        case loading
        case success(Status)
        case error(String)

        mutating func updateStatus(with result: Result<Status, Error>) {
            switch result {
            case .success(let status):
                self = .success(status)
            case .failure(let error):
                self = .error(error.localizedDescription)
            }
        }
    }

    var addressDescription: String {
        if self.host.contains(":") {
            // probably an IPv6 address
            return "[\(self.host)]:\(self.port)"
        } else {
            return "\(self.host):\(self.port)"
        }
    }

    // MARK: - Server Status Updates

    @MainActor
    func updateStatus() async {
        self.serverState = .loading

        let pingResult = await JavaServerPinger.shared.ping(host: self.host, port: self.port)

        switch pingResult {
        case .success(let (json, latency)):
            print("Ping successful: latency \(latency)ms")

            let parseResult = StatusDto.parse(json)
            switch parseResult {
            case .success(let dto):
                let status = dto.toStatus(latency: UInt64(latency))
                print("Parsed server status: \(status.players.online)/\(status.players.max) players online")
                self.serverState = .success(status)
                self.lastSeenDate = .now
            case .failure(let error):
                print("Failed to parse server status: \(error)")
                self.serverState = .error("Failed to parse server response")
            }
        case .failure(let error):
            print("Ping failed: \(error)")
            self.serverState = .error("Connection failed")
        }

        self.lastUpdatedDate = .now
    }
}
