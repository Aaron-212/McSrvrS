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
        let finalStatus: ServerStatus

        let pingResult = await JavaServerPinger.shared.ping(
            host: host,
            port: port
        )

        switch pingResult {
        case .success(let statusData):
            finalStatus = ServerStatus(
                server: self,
                state: .success(statusData)
            )
            lastSeenDate = .now
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
