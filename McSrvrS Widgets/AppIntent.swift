import WidgetKit
import AppIntents
import Foundation

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Server Status" }
    static var description: IntentDescription { "Displays the latest saved Minecraft server statuses." }

    @Parameter(title: "Server")
    var server: ServerSelectionEntity?
}

struct ServerSelectionEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Server")
    static var defaultQuery = ServerSelectionQuery()

    let id: String
    let name: String
    let address: String

    var uuid: UUID? {
        UUID(uuidString: id)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(address)"
        )
    }

    init(id: UUID, name: String, address: String) {
        self.id = id.uuidString
        self.name = name
        self.address = address
    }
}

struct ServerSelectionQuery: EntityQuery {
    func entities(for identifiers: [ServerSelectionEntity.ID]) async throws -> [ServerSelectionEntity] {
        let identifierSet = Set(identifiers)
        let selection = await WidgetServerStore.selection()

        return selection.servers
            .filter { identifierSet.contains($0.id.uuidString) }
            .map(ServerSelectionEntity.init(server:))
    }

    func suggestedEntities() async throws -> [ServerSelectionEntity] {
        let selection = await WidgetServerStore.selection()
        return selection.servers.map(ServerSelectionEntity.init(server:))
    }

    func defaultResult() async -> ServerSelectionEntity? {
        let selection = await WidgetServerStore.selection()
        return selection.servers.first.map(ServerSelectionEntity.init(server:))
    }
}

extension ServerSelectionEntity {
    init(server: Server) {
        self.init(
            id: server.id,
            name: server.name,
            address: server.address
        )
    }
}
