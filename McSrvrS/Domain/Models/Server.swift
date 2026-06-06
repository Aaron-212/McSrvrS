import Foundation
import SwiftData
import os

@Model
final class Server {
    // Calculated
    var id: UUID
    var orderIndex: Int
    // User defined
    var name: String
    var address: String
    // Auto generated
    @Relationship(deleteRule: .cascade, inverse: \ServerStatus.server)
    var statuses: [ServerStatus] = []
    var lastSeenDate: Date?
    var lastUpdatedDate: Date

    init(name: String, address: String, orderIndex: Int) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.name = name
        self.address = address
        self.lastUpdatedDate = Date.now
    }

    var addressDescription: String {
        address
    }

    // MARK: - Convenience Properties for Status

    var latestStatus: ServerStatus? {
        statuses.max { $0.timestamp < $1.timestamp }
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
        let status = ServerStatus(server: self, state: .loading)
        statuses.append(status)

        let pingResult = await JavaServerPinger.shared.ping(
            address: address
        )

        switch pingResult {
        case .success(let statusData):
            status.state = .success(statusData)
            lastSeenDate = .now
        case .failure(let error):
            status.state = .error(error.description)
        }

        status.timestamp = .now
        lastUpdatedDate = .now
        saveStatusUpdate()

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

    private func saveStatusUpdate() {
        do {
            try modelContext?.save()
        } catch {
            log.error("Could not save status update for server '\(self.name)': \(error.localizedDescription)")
        }
    }
}
