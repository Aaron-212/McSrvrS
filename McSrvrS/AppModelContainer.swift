import SwiftData

enum AppModelContainer {
    static let shared: ModelContainer = {
        do {
            return try make()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Server.self,
            ServerStatus.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
