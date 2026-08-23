import WidgetKit
import AppIntents
import Foundation
import SwiftData

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Server Status" }
    static var description: IntentDescription { "Displays the latest saved Minecraft server statuses." }

    @Parameter(title: "Server")
    var server: SelectedServerEntity?
    
    init(server: SelectedServerEntity? = nil) {
        self.server = server
    }
    
    init() {}
}

struct SelectedServerEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Server")
    static var defaultQuery = SelectedServerQuery()

    let id: String
    let name: String
    let address: String

    var serverID: UUID? {
        UUID(uuidString: id)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(address)"
        )
    }

    init(serverID: UUID, name: String, address: String) {
        self.id = serverID.uuidString
        self.name = name
        self.address = address
    }
    
    init(server: ServerSnapshot) {
        self.init(
            serverID: server.id,
            name: server.name,
            address: server.address
        )
    }
}

struct SelectedServerQuery: EntityQuery {
    typealias Entity = SelectedServerEntity

    func entities(for identifiers: [SelectedServerEntity.ID]) async throws -> [SelectedServerEntity] {
        let requestedIDs = Set(identifiers)
        return try Self.fetchEntities()
            .filter { requestedIDs.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SelectedServerEntity] {
        try Self.fetchEntities()
    }
    
    func defaultResult() async throws -> SelectedServerEntity? {
        try Self.fetchEntities().first
    }

    private static func fetchEntities() throws -> [SelectedServerEntity] {
        let container = WidgetModelContainer.shared
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Server>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )

        return try context
            .fetch(descriptor)
            .map(SelectedServerEntity.init(server:))
    }
}

extension SelectedServerEntity {
    init(server: Server) {
        self.init(
            serverID: server.id,
            name: server.name,
            address: server.address
        )
    }
}
