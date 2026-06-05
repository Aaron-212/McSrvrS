import Foundation
import Network
import os

actor JavaServerPinger: ServerPinger {
    static let shared = JavaServerPinger()

    private static let connectionTimeoutSeconds = 5

    private let logger: Logger

    private init() {
        self.logger = Logger(subsystem: "personal.aaron212.mcsrv", category: "JavaServerPinger")
    }

    private struct JavaStatusPlayerResponse: Codable {
        let name: String
        let playerId: String

        enum CodingKeys: String, CodingKey {
            case name
            case playerId = "id"
        }

        func toPlayer() -> ServerStatus.Player {
            ServerStatus.Player(name: name, playerId: playerId)
        }
    }

    private struct JavaStatusPlayersResponse: Codable {
        let max: UInt32
        let online: UInt32
        let sample: [JavaStatusPlayerResponse]?

        func toPlayers() -> ServerStatus.Players {
            ServerStatus.Players(
                max: max,
                online: online,
                sample: sample?.map { $0.toPlayer() }
            )
        }
    }

    private struct JavaStatusResponse: Codable {
        let version: ServerStatus.Version
        let players: JavaStatusPlayersResponse?
        let motd: String?
        let favicon: String?

        enum CodingKeys: String, CodingKey {
            case version, players, favicon
            case motd = "description"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            version = try container.decode(ServerStatus.Version.self, forKey: .version)
            players = try container.decodeIfPresent(JavaStatusPlayersResponse.self, forKey: .players)
            favicon = try container.decodeIfPresent(String.self, forKey: .favicon)

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
            ServerStatus.StatusData(
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
                let response = try JSONDecoder().decode(Self.self, from: data)
                return .success(response)
            } catch {
                return .failure(error)
            }
        }
    }

    func ping(host: String, port: UInt16) async -> Result<
        ServerStatus.StatusData, ServerPingerError
    > {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = await Self.connectionTimeoutSeconds
        tcpOptions.connectionDropTime = await Self.connectionTimeoutSeconds

        let connection = NWConnection(
            host: .init(host),
            port: .init(integerLiteral: port),
            using: .init(tls: nil, tcp: tcpOptions)
        )

        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    Task {
                        do {
                            let statusData = try await self.performPing(
                                connection: connection,
                                host: host,
                                port: port
                            )
                            connection.cancel()
                            continuation.resume(returning: .success(statusData))
                        } catch {
                            connection.cancel()
                            continuation.resume(returning: .failure(await Self.pingerError(from: error)))
                        }
                    }
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    connection.cancel()
                    continuation.resume(
                        returning: .failure(ServerPingerError.connectionFailed(error))
                    )
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
        try await sendHandshake(connection: connection, host: host, port: port)
        logger.debug("Handshake sent to \(host):\(port)")

        try await sendStatusRequest(connection: connection)
        logger.debug("Status request sent to \(host):\(port)")

        let jsonString = try await readStatusResponse(connection: connection)
        logger.debug("Status response received from \(host):\(port)")

        let latency = try await sendPingAndMeasureLatency(connection: connection)
        logger.debug("Ping response received from \(host):\(port) with latency \(latency) ms")

        switch JavaStatusResponse.parse(jsonString) {
        case .success(let response):
            logger.info("Ping successful for \(host):\(port)")
            return response.toStatusData(latency: UInt64(latency))
        case .failure(let error):
            logger.error("Failed to parse status JSON: \(error.localizedDescription)")
            throw ServerPingerError.dataError(
                "Failed to parse status JSON: \(error.localizedDescription)"
            )
        }
    }

    private static func pingerError(from error: Error) -> ServerPingerError {
        if let pingerError = error as? ServerPingerError {
            return pingerError
        }

        return .dataError(error.localizedDescription)
    }

    // Send handshake packet
    private func sendHandshake(connection: NWConnection, host: String, port: UInt16) async throws {
        var data = Data()

        // Packet ID (0x00 for handshake)
        data.append(packVarInt(0))

        // Protocol version (0 for status ping)
        data.append(packVarInt(0))

        // Server address
        let hostData = host.data(using: .utf8) ?? Data()
        data.append(packVarInt(hostData.count))
        data.append(hostData)

        // Server port
        data.append(Data([UInt8(port >> 8), UInt8(port & 0xFF)]))

        // Next state (1 for status)
        data.append(packVarInt(1))

        try await sendData(connection: connection, data: data)
    }

    // Send status request packet
    private func sendStatusRequest(connection: NWConnection) async throws {
        let data = packVarInt(0)  // Packet ID 0x00 for status request
        try await sendData(connection: connection, data: data)
    }

    // Read status response
    private func readStatusResponse(connection: NWConnection) async throws -> String {
        let data = try await readPacket(connection: connection, includesStringLength: true)

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ServerPingerError.encodingError
        }

        return jsonString
    }

    // Send ping packet and measure latency
    private func sendPingAndMeasureLatency(connection: NWConnection) async throws -> Int {
        let startTime = Int(Date().timeIntervalSince1970 * 1000)  // Current time in milliseconds

        var pingData = Data()
        pingData.append(packVarInt(1))  // Packet ID 0x01 for ping

        // Add timestamp (8 bytes, big endian)
        let timestamp = UInt64(startTime).bigEndian
        withUnsafeBytes(of: timestamp) { bytes in
            pingData.append(Data(bytes))
        }

        try await sendData(connection: connection, data: pingData)

        // Read pong response
        _ = try await readPacket(connection: connection, includesStringLength: false)

        let endTime = Int(Date().timeIntervalSince1970 * 1000)
        return endTime - startTime
    }

    // Send data with length prefix
    private func sendData(connection: NWConnection, data: Data) async throws {
        var packet = Data()
        packet.append(packVarInt(data.count))  // Length prefix
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
    private func readPacket(connection: NWConnection, includesStringLength: Bool) async throws -> Data {
        // Read packet length
        let packetLength = try await unpackVarInt(connection: connection)

        // Read packet ID
        let packetID = try await unpackVarInt(connection: connection)

        var remainingLength = packetLength - varIntSize(packetID)
        var resultData = Data()

        if includesStringLength {
            // For status response, read the JSON string length
            let jsonLength = try await unpackVarInt(connection: connection)
            remainingLength -= varIntSize(jsonLength)

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
                data,
                _,
                isComplete,
                error in
                if let error = error {
                    continuation.resume(throwing: ServerPingerError.connectionFailed(error))
                } else if let data = data, data.count == count {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(
                        throwing: ServerPingerError.dataError("Incomplete data received")
                    )
                }
            }
        }
    }

    // Pack varint (variable-length integer)
    private func packVarInt(_ value: Int) -> Data {
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
    private func unpackVarInt(connection: NWConnection) async throws -> Int {
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
    private func varIntSize(_ value: Int) -> Int {
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
