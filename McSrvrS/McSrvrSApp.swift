import SwiftData
import SwiftUI

@main
struct McSrvrSApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Server.self,
            ServerStatus.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        #if os(macOS)
            Window("McSrvrS", id: "main") {
                ContentView()
            }
            .modelContainer(sharedModelContainer)
        #else
            WindowGroup {
                ContentView()
            }
            .modelContainer(sharedModelContainer)
        #endif
    }
}
