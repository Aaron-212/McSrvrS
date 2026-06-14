#if os(iOS)
    import BackgroundTasks
#endif
import Foundation
import os
import SwiftData
import SwiftUI
#if canImport(WidgetKit)
    import WidgetKit
#endif

actor ServerRefreshService {
    @MainActor
    static func refresh(
        _ serverID: Server.ID,
        modelContainer: ModelContainer = AppModelContainer.shared
    ) async {
        do {
            guard let server = try fetchServer(with: serverID, in: modelContainer.mainContext) else {
                log.error("Could not find server to refresh: \(serverID)")
                return
            }

            await server.updateStatus()
        } catch {
            log.error("Server refresh failed: \(error)")
        }
    }

    @MainActor
    static func refreshAll(
        _ serverIDs: [Server.ID],
        modelContainer: ModelContainer = AppModelContainer.shared
    ) async {
        for serverID in serverIDs {
            await refresh(serverID, modelContainer: modelContainer)
        }
    }

    @MainActor
    private static func fetchServer(with serverID: Server.ID, in context: ModelContext) throws -> Server? {
        var descriptor = FetchDescriptor<Server>(
            predicate: #Predicate { server in
                server.id == serverID
            }
        )
        descriptor.fetchLimit = 1

        return try context.fetch(descriptor).first
    }
}

@MainActor
final class ServerRefreshCoordinator {
    private let modelContainer: ModelContainer
    private var hasPerformedInitialRefresh = false
    private var refreshTimer: Timer?
    #if os(macOS)
        private var backgroundActivityScheduler: NSBackgroundActivityScheduler?
    #endif

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func refreshAllServers() async {
        do {
            let context = modelContainer.mainContext
            let servers = try context.fetch(FetchDescriptor<Server>())
            await ServerRefreshService.refreshAll(
                servers.map(\.id),
                modelContainer: modelContainer
            )
            reloadWidgetTimelines()
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
        foregroundRefreshInterval: Double,
        backgroundRefreshInterval: Double,
        appRefreshTaskIdentifier: String
    ) {
        switch newPhase {
        case .active:
            if !hasPerformedInitialRefresh {
                hasPerformedInitialRefresh = true
                Task { await refreshAllServers() }
            }
            stopBackgroundRefreshScheduler()
            startForegroundRefreshTimer(interval: foregroundRefreshInterval)

        case .background:
            stopForegroundRefreshTimer()
            scheduleBackgroundRefresh(
                taskIdentifier: appRefreshTaskIdentifier,
                interval: backgroundRefreshInterval
            )

        case .inactive:
            stopForegroundRefreshTimer()
            #if os(iOS)
                break
            #else
                scheduleBackgroundRefresh(
                    taskIdentifier: appRefreshTaskIdentifier,
                    interval: backgroundRefreshInterval
                )
            #endif

        @unknown default:
            stopForegroundRefreshTimer()
            stopBackgroundRefreshScheduler()
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

    private func scheduleBackgroundRefresh(taskIdentifier: String, interval: Double) {
        #if os(iOS)
            Task {
                await scheduleNextRefresh(taskIdentifier: taskIdentifier, interval: interval)
            }
        #elseif os(macOS)
            scheduleMacOSBackgroundRefresh(taskIdentifier: taskIdentifier, interval: interval)
        #endif
    }

    private func stopBackgroundRefreshScheduler() {
        #if os(macOS)
            backgroundActivityScheduler?.invalidate()
            backgroundActivityScheduler = nil
        #endif
    }

    #if os(iOS)
        private func scheduleNextRefresh(taskIdentifier: String, interval: Double) async {
            guard interval > 0 else {
                log.info("Background refresh disabled")
                return
            }

            do {
                let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
                request.earliestBeginDate = .now.addingTimeInterval(interval)
                try BGTaskScheduler.shared.submit(request)
                log.info("App-refresh scheduled with interval: \(interval) seconds")
            } catch {
                log.error("Could not schedule app-refresh: \(error.localizedDescription)")
            }
        }
    #endif

    #if os(macOS)
        private func scheduleMacOSBackgroundRefresh(taskIdentifier: String, interval: Double) {
            stopBackgroundRefreshScheduler()

            guard interval > 0 else {
                log.info("Background refresh disabled")
                return
            }

            let scheduler = NSBackgroundActivityScheduler(identifier: taskIdentifier)
            scheduler.interval = interval
            scheduler.tolerance = min(interval * 0.25, 900)
            scheduler.repeats = true
            scheduler.qualityOfService = .utility
            scheduler.schedule { [weak self] completion in
                Task { @MainActor in
                    await self?.refreshAllServers()
                    completion(.finished)
                }
            }

            backgroundActivityScheduler = scheduler
            log.info("macOS background refresh scheduled with interval: \(interval) seconds")
        }
    #endif

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
