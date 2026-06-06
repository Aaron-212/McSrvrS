import AsyncDNSResolver
import Foundation
import os

nonisolated struct ResolvedServerAddress: Sendable {
    let host: String
    let port: UInt16
}

actor MinecraftSRVResolver {
    private static let logger = Logger(subsystem: "personal.aaron212.mcsrv", category: "MinecraftSRVResolver")
    private static let lookupTimeout: TimeInterval = 1
    private static let resolver: AsyncDNSResolver? = {
        var options = CAresDNSResolver.Options.default
        options.timeoutMillis = Int32(lookupTimeout * 1000)
        return try? AsyncDNSResolver(options: options)
    }()


    static func resolve(
        _ address: ServerAddress
    ) async -> ResolvedServerAddress {
        if let port = address.port {
            return ResolvedServerAddress(host: address.host, port: port)
        }

        guard let resolvedAddress = await resolveSRV(address)
        else {
            return ResolvedServerAddress(
                host: address.host,
                port: address.portForDirectConnection
            )
        }

        return resolvedAddress
    }

    static func resolveSRV(
        _ address: ServerAddress
    ) async -> ResolvedServerAddress? {
        guard address.shouldResolveSRV else {
            logger.debug("Skipping SRV lookup for \(address.description, privacy: .public)")
            return nil
        }

        logger.info("Starting SRV lookup for \(address.host, privacy: .public)")

        guard let record = await querySRVRecord(for: address.host) else {
            logger.info("No SRV record resolved for \(address.host, privacy: .public)")
            return nil
        }

        logger.info(
            "SRV lookup resolved \(address.host, privacy: .public) to \(record.host, privacy: .public):\(record.port)"
        )

        return ResolvedServerAddress(host: record.host, port: record.port)
    }

    private static func querySRVRecord(for host: String) async -> SRVRecord? {
        guard let resolver else {
            logger.error("SRV resolver could not be initialized")
            return nil
        }

        let queryName = "_minecraft._tcp.\(host)"

        do {
            let records = try await querySRVRecords(
                named: queryName,
                using: resolver
            )

            for record in records {
                logger.debug(
                    "SRV record received for \(host, privacy: .public): target=\(record.host, privacy: .public) port=\(record.port) priority=\(record.priority) weight=\(record.weight)"
                )
            }

            let selectedRecord = selectRecord(from: records)
            if let selectedRecord {
                logger.info(
                    "Selected SRV record for \(host, privacy: .public): \(selectedRecord.host, privacy: .public):\(selectedRecord.port)"
                )
            }

            return selectedRecord
        } catch is CancellationError {
            logger.debug("SRV lookup cancelled for \(queryName, privacy: .public)")
            return nil
        } catch {
            logger.info(
                "SRV lookup failed for \(queryName, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private static func querySRVRecords(
        named queryName: String,
        using resolver: AsyncDNSResolver
    ) async throws -> [SRVRecord] {
        try await resolver.querySRV(name: queryName)
    }

    private static func selectRecord(from records: [SRVRecord]) -> SRVRecord? {
        let minimumPriority = records.map(\.priority).min()
        let candidates = records.filter { $0.priority == minimumPriority }
        let totalWeight = candidates.reduce(UInt32(0)) { $0 + UInt32($1.weight) }

        guard totalWeight > 0 else {
            return candidates.first
        }

        var selectedWeight = UInt32.random(in: 1...totalWeight)
        for candidate in candidates {
            let weight = UInt32(candidate.weight)
            if selectedWeight <= weight {
                return candidate
            }
            selectedWeight -= weight
        }

        return candidates.last
    }
}
