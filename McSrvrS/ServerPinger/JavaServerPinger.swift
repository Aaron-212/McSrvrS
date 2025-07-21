import Foundation
import Network
import SwiftData
import os

// A dedicated service for handling Minecraft Server List Ping
actor JavaServerPinger: ServerPinger {
    static let shared = JavaServerPinger()
    let log: Logger

    private init() {
        self.log = Logger(subsystem: "personal.aaron212.mcsrv", category: "JavaServerPinger")
    }

    private struct PlayerDto: Codable {
        let name: String
        let playerId: String

        enum CodingKeys: String, CodingKey {
            case name
            case playerId = "id"
        }

        func toPlayer() -> ServerStatus.Player {
            return ServerStatus.Player(name: name, playerId: playerId)
        }
    }

    private struct PlayersDto: Codable {
        let max: UInt32
        let online: UInt32
        let sample: [PlayerDto]?

        func toPlayers() -> ServerStatus.Players {
            return ServerStatus.Players(
                max: max,
                online: online,
                sample: sample?.map { $0.toPlayer() }
            )
        }
    }

    private struct JavaStatusDto: Codable {
        let version: ServerStatus.Version
        let players: PlayersDto?
        let motd: String?
        let favicon: String?

        enum CodingKeys: String, CodingKey {
            case version, players, favicon
            case motd = "description"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            version = try container.decode(ServerStatus.Version.self, forKey: .version)
            players = try container.decodeIfPresent(PlayersDto.self, forKey: .players)
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
                players: players?.toPlayers(),
                motd: motd,
                favicon: favicon,
                latency: latency
            )
        }

        static func parse(_ jsonString: String) -> Result<Self, Error> {
            guard let data = jsonString.data(using: .utf8) else {
                return .failure(NSError(domain: "InvalidString", code: 1, userInfo: nil))
            }

            do {
                let dto = try JSONDecoder().decode(Self.self, from: data)
                return .success(dto)
            } catch {
                return .failure(error)
            }
        }
    }

    func ping(host: String, port: UInt16) async -> Result<
        ServerStatus.StatusData, ServerPingerError
    > {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 5
        tcpOptions.connectionDropTime = 5

        let connection = NWConnection(
            host: .init(host),
            port: .init(integerLiteral: port),
            using: .init(tls: nil, tcp: tcpOptions)
        )

        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    Task {
                        do {
                            let statusData = try await self.performPing(
                                connection: connection, host: host, port: port)
                            connection.cancel()
                            continuation.resume(returning: .success(statusData))
                        } catch {
                            connection.cancel()
                            continuation.resume(returning: .failure(error as! ServerPingerError))
                        }
                    }
                case .failed(let error):
                    connection.cancel()
                    continuation.resume(
                        returning: .failure(ServerPingerError.connectionFailed(error)))
                case .cancelled:
                    break
                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    // Perform the complete ping sequence
    private func performPing(connection: NWConnection, host: String, port: UInt16) async throws
        -> ServerStatus.StatusData
    {
        // Send handshake packet
        try await sendHandshake(connection: connection, host: host, port: port)
        log.debug("Handshake sent to \(host):\(port)")

        // Send status request
        try await sendStatusRequest(connection: connection)
        log.debug("Status request sent to \(host):\(port)")

        // Read status response
        let jsonString = try await readStatusResponse(connection: connection)
        log.debug("Status response received from \(host):\(port)")

        // Send ping packet and measure latency
        let latency = try await sendPingAndMeasureLatency(connection: connection)
        log.debug("Ping response received from \(host):\(port) with latency \(latency) ms")

        // Parse the JSON response
        switch JavaStatusDto.parse(jsonString) {
        case .success(let dto):
            log.info("Ping successful for \(host):\(port)")
            return dto.toStatusData(latency: UInt64(latency))
        case .failure(let error):
            log.error("Failed to parse status JSON: \(error.localizedDescription)")
            throw ServerPingerError.dataError(
                "Failed to parse status JSON: \(error.localizedDescription)")
        }
    }

    // Send handshake packet
    private func sendHandshake(connection: NWConnection, host: String, port: UInt16) async throws {
        var data = Data()

        // Packet ID (0x00 for handshake)
        data.append(packVarint(0))

        // Protocol version (0 for status ping)
        data.append(packVarint(0))

        // Server address
        let hostData = host.data(using: .utf8) ?? Data()
        data.append(packVarint(hostData.count))
        data.append(hostData)

        // Server port
        data.append(Data([UInt8(port >> 8), UInt8(port & 0xFF)]))

        // Next state (1 for status)
        data.append(packVarint(1))

        try await sendData(connection: connection, data: data)
    }

    // Send status request packet
    private func sendStatusRequest(connection: NWConnection) async throws {
        let data = packVarint(0)  // Packet ID 0x00 for status request
        try await sendData(connection: connection, data: data)
    }

    // Read status response
    private func readStatusResponse(connection: NWConnection) async throws -> String {
        let data = try await readPacket(connection: connection, extraVarint: true)

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ServerPingerError.encodingError
        }

        return jsonString
    }

    // Send ping packet and measure latency
    private func sendPingAndMeasureLatency(connection: NWConnection) async throws -> Int {
        let startTime = Int(Date().timeIntervalSince1970 * 1000)  // Current time in milliseconds

        var pingData = Data()
        pingData.append(packVarint(1))  // Packet ID 0x01 for ping

        // Add timestamp (8 bytes, big endian)
        let timestamp = UInt64(startTime).bigEndian
        withUnsafeBytes(of: timestamp) { bytes in
            pingData.append(Data(bytes))
        }

        try await sendData(connection: connection, data: pingData)

        // Read pong response
        _ = try await readPacket(connection: connection, extraVarint: false)

        let endTime = Int(Date().timeIntervalSince1970 * 1000)
        return endTime - startTime
    }

    // Send data with length prefix
    private func sendData(connection: NWConnection, data: Data) async throws {
        var packet = Data()
        packet.append(packVarint(data.count))  // Length prefix
        packet.append(data)

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: packet,
                completion: .contentProcessed { error in
                    if let error = error {
                        continuation.resume(throwing: ServerPingerError.connectionFailed(error))
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    // Read a complete packet
    private func readPacket(connection: NWConnection, extraVarint: Bool) async throws -> Data {
        // Read packet length
        let packetLength = try await unpackVarint(connection: connection)

        // Read packet ID
        let packetId = try await unpackVarint(connection: connection)

        var remainingLength = packetLength - varintSize(packetId)
        var resultData = Data()

        if extraVarint {
            // For status response, read the JSON string length
            let jsonLength = try await unpackVarint(connection: connection)
            remainingLength -= varintSize(jsonLength)

            // Read the JSON string
            resultData = try await readBytes(connection: connection, count: jsonLength)
        } else {
            // For ping response, read remaining data
            if remainingLength > 0 {
                resultData = try await readBytes(connection: connection, count: remainingLength)
            }
        }

        return resultData
    }

    // Read exact number of bytes
    private func readBytes(connection: NWConnection, count: Int) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: count, maximumLength: count) {
                data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: ServerPingerError.connectionFailed(error))
                } else if let data = data, data.count == count {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(
                        throwing: ServerPingerError.dataError("Incomplete data received"))
                }
            }
        }
    }

    // Pack varint (variable-length integer)
    private func packVarint(_ value: Int) -> Data {
        var data = Data()
        var val = value

        repeat {
            var byte = UInt8(val & 0x7F)
            val >>= 7
            if val != 0 {
                byte |= 0x80
            }
            data.append(byte)
        } while val != 0

        return data
    }

    // Unpack varint from connection
    private func unpackVarint(connection: NWConnection) async throws -> Int {
        var result = 0
        var position = 0

        for _ in 0..<5 {
            let byteData = try await readBytes(connection: connection, count: 1)
            let byte = byteData[0]

            result |= Int(byte & 0x7F) << (7 * position)

            if (byte & 0x80) == 0 {
                break
            }

            position += 1
        }

        return result
    }

    // Calculate the size of a varint
    private func varintSize(_ value: Int) -> Int {
        if value == 0 { return 1 }
        var size = 0
        var val = value
        while val > 0 {
            size += 1
            val >>= 7
        }
        return size
    }
}
