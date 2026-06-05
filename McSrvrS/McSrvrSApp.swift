#if os(iOS)
    import BackgroundTasks
#endif
import SwiftData
import SwiftUI

@main
struct McSrvrSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKey.foregroundRefreshInterval) private var foregroundRefreshInterval: Double = 300
    @AppStorage(AppStorageKey.backgroundRefreshInterval) private var backgroundRefreshInterval: Double = 900
    @State private var refreshCoordinator = ServerRefreshCoordinator(
        modelContainer: AppModelContainer.shared
    )

    private static let appRefreshTaskIdentifier = "personal.aaron212.mcsrvrs.refresh"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: foregroundRefreshInterval) { _, _ in
                    refreshCoordinator.refreshIntervalDidChange(
                        to: foregroundRefreshInterval,
                        scenePhase: scenePhase
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: .refreshIntervalChanged)) { _ in
                    refreshCoordinator.refreshIntervalDidChange(
                        to: foregroundRefreshInterval,
                        scenePhase: scenePhase
                    )
                }
        }
        .modelContainer(AppModelContainer.shared)
        .commandsReplaced {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button {
                    NotificationCenter.default.post(name: .addNewServer, object: nil)
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button {
                    NotificationCenter.default.post(name: .refreshThisServer, object: nil)
                } label: {
                    Label("Refresh This Server", systemImage: "arrow.trianglehead.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button {
                    NotificationCenter.default.post(name: .refreshAllServers, object: nil)
                } label: {
                    Label("Refresh All Servers", systemImage: "arrow.trianglehead.2.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh(Self.appRefreshTaskIdentifier)) {
            await refreshCoordinator.refreshAllServers()
        }
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            refreshCoordinator.scenePhaseDidChange(
                to: newPhase,
                foregroundRefreshInterval: foregroundRefreshInterval,
                backgroundRefreshInterval: backgroundRefreshInterval,
                appRefreshTaskIdentifier: Self.appRefreshTaskIdentifier
            )
        }

        #if os(macOS)
            Settings {
                SettingsView()
            }
        #endif
    }
}
