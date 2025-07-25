import SwiftData
import SwiftUI

struct EmptyStateView: View {
    let hasServers: Bool
    let isFiltering: Bool
    let searchText: String
    let addServerAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasServers ? "magnifyingglass" : "server.rack")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            VStack {
                Text(titleText)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(subtitleText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !hasServers {
                Button(action: addServerAction) {
                    Label("Add Server", systemImage: "plus")
                        .font(.headline)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var titleText: LocalizedStringResource {
        if !hasServers {
            return "No Servers Added"
        } else if isFiltering && !searchText.isEmpty {
            return "No Results"
        } else if isFiltering {
            return "No Online Servers"
        } else {
            return "No Results"
        }
    }

    private var subtitleText: LocalizedStringResource {
        if !hasServers {
            return "Add your first Minecraft server to get started"
        } else if isFiltering && !searchText.isEmpty {
            return "No online servers matching \"\(searchText)\""
        } else if isFiltering {
            return "All servers are currently offline"
        } else {
            return "No servers matching \"\(searchText)\""
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \Server.orderIndex) private var servers: [Server]
    @State private var searchText = ""
    @State private var showingServerForm = false
    @State private var showingSettings = false
    @State private var isFiltering = false

    private var filteredServers: [Server] {
        let searchFiltered =
            searchText.isEmpty
            ? servers
            : servers.filter { server in
                server.name.localizedCaseInsensitiveContains(searchText)
                    || server.addressDescription.localizedCaseInsensitiveContains(searchText)
            }

        if !isFiltering {
            return searchFiltered
        } else {
            return searchFiltered.filter { server in
                server.isOnline
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if servers.isEmpty {
                    // Fallback view when no servers exist
                    EmptyStateView(
                        hasServers: false,
                        isFiltering: isFiltering,
                        searchText: searchText,
                        addServerAction: addServer
                    )
                } else if filteredServers.isEmpty {
                    // Fallback view when servers exist but filtered results are empty
                    EmptyStateView(
                        hasServers: true,
                        isFiltering: isFiltering,
                        searchText: searchText,
                        addServerAction: addServer
                    )
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
        .searchable(text: $searchText, prompt: "Search Servers")
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
        Toggle(isOn: $isFiltering) {
            Label("Filter Servers", systemImage: "line.3.horizontal.decrease")
        }
    }

    private var addServerButton: some View {
        Button(action: addServer) {
            Label("Add Server", systemImage: "plus")
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
        var mutableServers = servers
        mutableServers.move(fromOffsets: source, toOffset: destination)
        for index in 0..<mutableServers.count {
            mutableServers[index].orderIndex = index
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
