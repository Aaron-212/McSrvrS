import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \Server.orderIndex) private var servers: [Server]
    @State private var searchText = ""
    @State private var showingServerForm = false
    @State private var showingSettings = false
    @State private var showsOnlineOnly = false

    private var filteredServers: [Server] {
        let matchingServers =
            searchText.isEmpty
            ? servers
            : servers.filter { server in
                server.name.localizedCaseInsensitiveContains(searchText)
                    || server.addressDescription.localizedCaseInsensitiveContains(searchText)
            }

        guard showsOnlineOnly else {
            return matchingServers
        }

        return matchingServers.filter { server in
            server.isOnline
        }
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if servers.isEmpty {
                    unavailableContent(hasServers: false)
                } else if filteredServers.isEmpty {
                    unavailableContent(hasServers: true)
                } else {
                    List {
                        ForEach(filteredServers) { server in
                            NavigationLink {
                                ServerDetailView(server: server)
                            } label: {
                                ServerItemView(server: server)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task {
                                        await server.updateStatus()
                                    }
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                                .tint(.accentColor)
                            }
                        }
                        .onDelete(perform: deleteServers)
                        .onMove(perform: moveServers)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("McSrvrS")
            #if os(macOS)
                .navigationSplitViewColumnWidth(min: 250, ideal: 320)
            #endif
            .toolbar {
                #if os(iOS)
                    if horizontalSizeClass == .compact {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showingSettings = true }) {
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
                #else
                    ToolbarItem(placement: .automatic) {
                        Button(action: refreshAllServers) {
                            Label("Refresh All Servers", systemImage: "arrow.trianglehead.2.clockwise")
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
                refreshAllServers()
            }
        } detail: {
            Text("Select a Server")
                .font(.title)
                .foregroundStyle(.tertiary)
                .bold()
                #if os(macOS)
                    .navigationSplitViewColumnWidth(min: 320, ideal: 400)
                #endif
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search Servers")
        .sheet(isPresented: $showingServerForm) {
            ServerForm()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewServer)) { _ in
            addServer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshAllServers)) { _ in
            refreshAllServers()
        }
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

    private func unavailableContent(hasServers: Bool) -> some View {
        ContentUnavailableView {
            Label(
                unavailableContentTitle(hasServers: hasServers),
                systemImage: hasServers ? "magnifyingglass" : "server.rack"
            )
        } description: {
            Text(unavailableContentDescription(hasServers: hasServers))
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

    private func unavailableContentTitle(hasServers: Bool) -> LocalizedStringResource {
        if !hasServers {
            return "No Servers Added"
        } else if showsOnlineOnly && !searchText.isEmpty {
            return "No Results"
        } else if showsOnlineOnly {
            return "No Online Servers"
        } else {
            return "No Results"
        }
    }

    private func unavailableContentDescription(hasServers: Bool) -> LocalizedStringResource {
        if !hasServers {
            return "Add your first Minecraft server to get started"
        } else if showsOnlineOnly && !searchText.isEmpty {
            return "No online servers matching \"\(searchText)\""
        } else if showsOnlineOnly {
            return "All servers are currently offline"
        } else {
            return "No servers matching \"\(searchText)\""
        }
    }

    private func addServer() {
        showingServerForm = true
    }

    private func deleteServers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredServers[index])
            }
        }
    }

    private func moveServers(source: IndexSet, destination: Int) {
        var reorderedVisibleServers = filteredServers
        reorderedVisibleServers.move(fromOffsets: source, toOffset: destination)

        let visibleServerIDs = Set(filteredServers.map(\.id))
        var visibleServerIterator = reorderedVisibleServers.makeIterator()
        let reorderedServers = servers.map { server in
            visibleServerIDs.contains(server.id)
                ? (visibleServerIterator.next() ?? server)
                : server
        }

        for (index, server) in reorderedServers.enumerated() {
            server.orderIndex = index
        }
    }

    private func refreshAllServers() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for server in servers {
                    group.addTask {
                        await server.updateStatus()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Server.self, inMemory: true)
}
