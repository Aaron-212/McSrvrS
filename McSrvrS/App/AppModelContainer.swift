import SwiftData

enum AppModelContainer {
    static let appGroupIdentifier = "group.aaron212.mcsrvrs"

    static let shared: ModelContainer = {
        do {
            return try make()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    static func make(
        isStoredInMemoryOnly: Bool = false,
        allowsSave: Bool = true
    ) throws -> ModelContainer {
        let schema = Schema([
            Server.self,
            ServerStatus.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            allowsSave: allowsSave,
            groupContainer: isStoredInMemoryOnly ? .none : .identifier(appGroupIdentifier)
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
