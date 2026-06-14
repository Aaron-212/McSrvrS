import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \Server.orderIndex) private var servers: [Server]
    @State private var searchText = ""
    @State private var presentedSheet: ContentSheet?
    @State private var selectedServerID: Server.ID? = nil
    @State private var showsOnlineOnly = false

    private var filter: ServerListFilter {
        ServerListFilter(searchText: searchText, showsOnlineOnly: showsOnlineOnly)
    }

    private var filteredServers: [Server] {
        filter.apply(to: servers)
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if servers.isEmpty {
                    unavailableContent(hasServers: false)
                } else if filteredServers.isEmpty {
                    unavailableContent(hasServers: true)
                } else {
                    List(selection: $selectedServerID) {
                        ForEach(filteredServers) { server in
                            serverRow(server)
                        }
                        .onDelete(perform: deleteServers)
                        .onMove(perform: moveServers)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("McSrvrS")
            .navigationSubtitle("\(filteredServers.count) Servers")
            #if os(macOS)
                .navigationSplitViewColumnWidth(min: 250, ideal: 320)
            #endif
            .toolbar {
                #if os(iOS)
                    if horizontalSizeClass == .compact {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { presentedSheet = .settings }) {
                                Label("Settings", systemImage: "gear")
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            EditButton()
                        }
                        ToolbarItemGroup(placement: .bottomBar) {
                            filterServerButton
                        }
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                        DefaultToolbarItem(kind: .search, placement: .bottomBar)
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                        ToolbarItem(placement: .bottomBar) {
                            addServerButton
                        }
                    } else {
                        ToolbarItem(placement: .automatic) {
                            filterServerButton
                        }
                        ToolbarItem(placement: .automatic) {
                            addServerButton
                        }
                    }
                #elseif os(macOS)
                    if #unavailable(anyAppleOS 26) {
                        ToolbarItem(placement: .automatic) {
                            Button {
                                Task { await refreshAllServers() }
                            } label: {
                                Label("Refresh All Servers", systemImage: "arrow.trianglehead.2.clockwise")
                            }
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        filterServerButton
                    }
                    ToolbarItem(placement: .automatic) {
                        addServerButton
                    }
                #endif
            }
            .refreshable {
                await refreshAllServers()
            }
        } detail: {
            if let selectedServerID {
                ServerDetailView(serverID: selectedServerID)
                    .navigationSplitViewColumnWidth(min: 320, ideal: 400)
            } else {
                Text("Select a Server")
                    .font(.title)
                    .foregroundStyle(.tertiary)
                    .bold()
                    .navigationSplitViewColumnWidth(min: 320, ideal: 400)
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search Servers")
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .serverForm:
                ServerForm()
                    .presentationDetents([.medium, .large])
            case .settings:
                SettingsView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewServer)) { _ in
            addServer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshAllServers)) { _ in
            Task { await refreshAllServers() }
        }
        .onOpenURL(perform: openDeepLink)
    }

    private var filterServerButton: some View {
        Toggle(isOn: $showsOnlineOnly) {
            Label("Filter Servers", systemImage: "line.3.horizontal.decrease")
        }
    }

    private var addServerButton: some View {
        Button(action: addServer) {
            Label("Add Server", systemImage: "plus")
        }
    }

    private func serverRow(_ server: Server) -> some View {
        NavigationLink(value: server.id) {
            ServerItemView(server: server)
        }
        .swipeActions(edge: .leading) {
            refreshServerButton(serverID: server.id)
        }
    }

    private func refreshServerButton(serverID: Server.ID) -> some View {
        Button {
            Task {
                await ServerRefreshService.refresh(
                    serverID,
                    modelContainer: modelContext.container
                )
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .tint(.accentColor)
    }

    private func unavailableContent(hasServers: Bool) -> some View {
        ContentUnavailableView {
            Label(
                filter.unavailableContentTitle(hasServers: hasServers),
                systemImage: hasServers ? "magnifyingglass" : "server.rack"
            )
        } description: {
            Text(filter.unavailableContentDescription(hasServers: hasServers))
        } actions: {
            if !hasServers {
                Button(action: addServer) {
                    Label("Add Server", systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        }
    }

    private func addServer() {
        presentedSheet = .serverForm
    }

    private func deleteServers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredServers[index])
            }
        }
    }

    private func moveServers(source: IndexSet, destination: Int) {
        let reorderedServers = ServerListOrdering.reorderedServers(
            all: servers,
            visibleServers: filteredServers,
            source: source,
            destination: destination
        )

        for (index, server) in reorderedServers.enumerated() {
            server.orderIndex = index
        }
    }

    private func refreshAllServers() async {
        await ServerRefreshService.refreshAll(
            servers.map(\.id),
            modelContainer: modelContext.container
        )
    }

    private func openDeepLink(_ url: URL) {
        guard let serverID = ServerDeepLink.serverID(from: url) else { return }

        presentedSheet = nil
        searchText = ""
        showsOnlineOnly = false
        selectedServerID = serverID
    }
}

private enum ServerDeepLink {
    private static let scheme = "mcsrvrs"
    private static let serverHost = "server"

    static func serverID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host == serverHost else { return nil }

        return url.pathComponents
            .dropFirst()
            .first
            .flatMap(UUID.init(uuidString:))
    }
}

private enum ContentSheet: Identifiable {
    case serverForm
    case settings

    var id: String {
        switch self {
        case .serverForm:
            return "serverForm"
        case .settings:
            return "settings"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Server.self, inMemory: true)
}
