#if os(iOS)
    import BackgroundTasks
#endif
import Foundation
import os
import SwiftData
import SwiftUI

@MainActor
enum ServerRefreshService {
    static func refresh(_ server: Server) async {
        await server.updateStatus()
    }

    static func refreshAll(_ servers: [Server]) async {
        await withTaskGroup(of: Void.self) { group in
            for server in servers {
                group.addTask {
                    await server.updateStatus()
                }
            }
        }
    }
}

@MainActor
final class ServerRefreshCoordinator {
    private let modelContainer: ModelContainer
    private var hasPerformedInitialRefresh = false
    private var refreshTimer: Timer?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func refreshAllServers() async {
        do {
            let context = ModelContext(modelContainer)
            let servers = try context.fetch(FetchDescriptor<Server>())
            await ServerRefreshService.refreshAll(servers)
        } catch {
            log.error("Server refresh failed: \(error)")
        }
    }

    func refreshIntervalDidChange(to refreshInterval: Double, scenePhase: ScenePhase) {
        guard scenePhase == .active else {
            return
        }

        startForegroundRefreshTimer(interval: refreshInterval)
    }

    func scenePhaseDidChange(
        to newPhase: ScenePhase,
        refreshInterval: Double,
        appRefreshTaskIdentifier: String
    ) {
        switch newPhase {
        case .active:
            if !hasPerformedInitialRefresh {
                hasPerformedInitialRefresh = true
                Task { await refreshAllServers() }
            }
            startForegroundRefreshTimer(interval: refreshInterval)

        case .background:
            stopForegroundRefreshTimer()
            #if os(iOS)
                Task { await scheduleNextRefresh(taskIdentifier: appRefreshTaskIdentifier) }
            #endif

        case .inactive:
            stopForegroundRefreshTimer()

        @unknown default:
            stopForegroundRefreshTimer()
        }
    }

    private func startForegroundRefreshTimer(interval refreshInterval: Double) {
        stopForegroundRefreshTimer()

        guard refreshInterval > 0 else {
            log.info("Foreground refresh disabled")
            return
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAllServers()
            }
        }
        log.info("Foreground refresh timer started with interval: \(refreshInterval) seconds")
    }

    private func stopForegroundRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    #if os(iOS)
        private func scheduleNextRefresh(taskIdentifier: String) async {
            do {
                let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
                request.earliestBeginDate = .now.addingTimeInterval(60 * 15)
                try BGTaskScheduler.shared.submit(request)
                log.info("App-refresh scheduled")
            } catch {
                log.error("Could not schedule app-refresh: \(error.localizedDescription)")
            }
        }
    #endif
}
