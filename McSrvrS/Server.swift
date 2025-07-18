import Foundation
import Network
import SwiftData
import os

@Model
final class Server {
    // Calculated
    var id: UUID
    var orderIndex: Int
    // User defined
    var name: String
    var host: String
    var port: UInt16
    // Auto generated
    @Relationship(deleteRule: .cascade, inverse: \ServerStatus.server)
    var statuses: [ServerStatus] = []
    var lastSeenDate: Date?
    var lastUpdatedDate: Date

    init(name: String, host: String, port: UInt16 = 25565, orderIndex: Int) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.name = name
        self.host = host
        self.port = port
        self.lastUpdatedDate = Date.now
    }

    // MARK: - External DTO (JSON Parsing)

    private struct StatusDto: Codable {
        let version: ServerStatus.Version
        let players: ServerStatus.Players?
        let motd: String?
        let favicon: String?

        enum CodingKeys: String, CodingKey {
            case version, players, favicon
            case motd = "description"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            version = try container.decode(ServerStatus.Version.self, forKey: .version)
            players = try container.decode(ServerStatus.Players.self, forKey: .players)
            favicon = try container.decodeIfPresent(String.self, forKey: .favicon)

            // Handle motd which can be either string or object with text field
            if let motdString = try? container.decode(String.self, forKey: .motd) {
                motd = motdString
            } else if let motdObject = try? container.decode([String: String].self, forKey: .motd),
                let text = motdObject["text"]
            {
                motd = text
            } else {
                motd = nil
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(version, forKey: .version)
            try container.encode(players, forKey: .players)
            try container.encode(motd, forKey: .motd)
            try container.encodeIfPresent(favicon, forKey: .favicon)
        }

        func toStatusData(latency: UInt64?) -> ServerStatus.StatusData {
            return ServerStatus.StatusData(
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

    var addressDescription: String {
        if self.host.contains(":") {
            // probably an IPv6 address
            return "[\(self.host)]:\(self.port)"
        } else {
            return "\(self.host):\(self.port)"
        }
    }

    // MARK: - Convenience Properties for Status

    var latestStatus: ServerStatus? {
        return statuses.sorted(by: { $0.timestamp > $1.timestamp }).first
    }

    var currentState: ServerStatus.StatusState {
        return latestStatus?.state ?? .loading
    }

    var isOnline: Bool {
        if case .success = currentState { return true }
        return false
    }

    // MARK: - Server Status Updates

    @MainActor
    func updateStatus() async {
        statuses.append(ServerStatus(server: self, state: .loading))
        let indexOfPlaceholder = statuses.count - 1

        let pingResult = await JavaServerPinger.shared.ping(
            host: host,
            port: port
        )

        let finalStatus: ServerStatus
        switch pingResult {
        case .success(let (json, latency)):
            switch StatusDto.parse(json) {
            case .success(let dto):
                finalStatus = ServerStatus(
                    server: self,
                    state: .success(dto.toStatusData(latency: UInt64(latency)))
                )
                lastSeenDate = .now
            case .failure(let error):
                finalStatus = ServerStatus(
                    server: self,
                    state: .error(error.localizedDescription)
                )
            }
        case .failure(let error):
            finalStatus = ServerStatus(
                server: self,
                state: .error(error.description)
            )
        }

        lastUpdatedDate = .now
        statuses[indexOfPlaceholder] = finalStatus

        if statuses.count % 10 == 0 {
            cleanupOldStatuses()
        }
    }

    // MARK: - Cleanup

    private func cleanupOldStatuses() {
        guard let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date.now) else {
            return
        }

        let initialCount = statuses.count
        statuses.removeAll { $0.timestamp < oneYearAgo }

        let removedCount = initialCount - statuses.count
        if removedCount > 0 {
            log.info("Cleaned up \(removedCount) old status records for server '\(self.name)'")
        }
    }
}
