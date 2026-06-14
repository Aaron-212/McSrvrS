import SwiftData

actor WidgetModelContainer {
    static let appGroupIdentifier = "group.aaron212.mcsrvrs"

    static let shared: ModelContainer = {
        do {
            return try make(allowsSave: false)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    static func make(allowsSave: Bool = true) throws -> ModelContainer {
        let schema = Schema([
            Server.self,
            ServerStatus.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            allowsSave: allowsSave,
            groupContainer: .identifier(appGroupIdentifier)
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
