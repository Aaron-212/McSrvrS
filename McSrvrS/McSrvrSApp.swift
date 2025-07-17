import BackgroundTasks
import SwiftData
import SwiftUI
import os

@main
struct McSrvrSApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private static let refreshID = "personal.aaron212.mcsrvrs.refresh"

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
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        #if os(iOS)
            .backgroundTask(.appRefresh(Self.refreshID)) {
                await handleAppRefresh()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    Task { await scheduleNextRefresh() }
                }
            }
        #endif

        #if os(macOS)
            Settings {
                SettingsView()
            }
        #endif
    }

    private func handleAppRefresh() async {
        do {
            // Create a model context for background operations
            let context = ModelContext(sharedModelContainer)

            // Fetch all servers
            let descriptor = FetchDescriptor<Server>()
            let servers = try context.fetch(descriptor)

            // Update server statuses concurrently
            await withTaskGroup(of: Void.self) { group in
                for server in servers {
                    group.addTask {
                        await server.updateStatus()
                    }
                }
            }
        } catch {
            log.error("Background refresh failed: \(error)")
        }
    }

    #if os(iOS)
        private func scheduleNextRefresh() async {
            do {
                var request = BGAppRefreshTaskRequest(identifier: Self.refreshID)
                request.earliestBeginDate = .now.addingTimeInterval(60 * 15)  // 15 mins
                try BGTaskScheduler.shared.submit(request)
                log.info("App-refresh scheduled")
            } catch {
                log.error("Could not schedule app-refresh: \(error.localizedDescription)")
            }
        }
    #endif
}
