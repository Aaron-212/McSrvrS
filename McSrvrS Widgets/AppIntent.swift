import WidgetKit
import AppIntents
import Foundation
import SwiftData
import CoreSpotlight

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Server Status" }
    static var description: IntentDescription { "Displays the latest saved Minecraft server statuses." }

    @Parameter(title: "Server")
    var server: SelectedServerEntity?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Server \(\.$server)")
    }
}

struct SelectedServerEntity: AppEntity, IndexedEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Server")
    static var defaultQuery = SelectedServerQuery()

    let id: UUID
    @Property(title: "Name") var name: String
    @Property(title: "Address") var address: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(address)"
        )
    }

    init(id: Self.ID, name: String, address: String) {
        self.id = id
        self.name = name
        self.address = address
    }
    
    init(server: ServerSnapshot) {
        self.id = server.id
        self.name = server.name
        self.address = server.address
    }
}

struct SelectedServerQuery: EntityQuery {
    typealias Entity = SelectedServerEntity

    func entities(for identifiers: [SelectedServerEntity.ID]) async throws -> [SelectedServerEntity] {
        let container = WidgetModelContainer.shared
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Server>(
            predicate: #Predicate { identifiers.contains($0.id) },
            sortBy: [SortDescriptor(\.orderIndex)]
        )

        return try context
            .fetch(descriptor)
            .map(SelectedServerEntity.init(server:))
    }

    func suggestedEntities() async throws -> [SelectedServerEntity] {
        let container = WidgetModelContainer.shared
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Server>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )

        let servers = try context
            .fetch(descriptor)
            .map(SelectedServerEntity.init(server:))
        return servers
    }
    
    func defaultResult() async throws -> SelectedServerEntity? {
        let container = WidgetModelContainer.shared
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Server>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )

        let server = try context
            .fetch(descriptor)
            .first
            .map(SelectedServerEntity.init(server:))
        return server
    }
}

@available(iOS 27, macOS 27, *)
extension SelectedServerQuery: IndexedEntityQuery {
    func reindexEntities(
        for identifiers: [SelectedServerEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let container = WidgetModelContainer.shared
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Server>(
            predicate: #Predicate { identifiers.contains($0.id) },
            sortBy: [SortDescriptor(\.orderIndex)]
        )

        let servers = try context
            .fetch(descriptor)
            .map(SelectedServerEntity.init(server:))
        
        try await CSSearchableIndex(name: "McSrvrS").indexAppEntities(servers)
    }
    
    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let container = WidgetModelContainer.shared
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Server>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )

        let servers = try context
            .fetch(descriptor)
            .map(SelectedServerEntity.init(server:))
        
        try await CSSearchableIndex(name: "McSrvrS").indexAppEntities(servers)
    }
}

extension SelectedServerEntity {
    init(server: Server) {
        self.init(
            id: server.id,
            name: server.name,
            address: server.address
        )
    }
}
