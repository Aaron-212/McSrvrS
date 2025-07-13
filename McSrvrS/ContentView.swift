import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var servers: [Server]
    @State private var searchText = ""
    @State private var showingServerForm = false
    @State private var showingServerFilter = false
    @State private var filterMode: FilterMode = .all

    enum FilterMode: String, CaseIterable {
        case all = "All Servers"
        case online = "Online Only"
        case offline = "Offline Only"
    }

    private var filteredServers: [Server] {
        let searchFiltered =
            searchText.isEmpty
            ? servers
            : servers.filter { server in
                server.name.localizedCaseInsensitiveContains(searchText)
                    || server.addressDescription.localizedCaseInsensitiveContains(searchText)
            }

        switch filterMode {
        case .all:
            return searchFiltered
        case .online:
            return searchFiltered.filter { server in
                if case .success = server.serverState {
                    return true
                }
                return false
            }
        case .offline:
            return searchFiltered.filter { server in
                if case .error = server.serverState {
                    return true
                }
                return false
            }
        }
    }

    var body: some View {
        NavigationSplitView {
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
            }
            .listStyle(.plain)
            .navigationTitle("McSrvrS")
            #if os(macOS)
                .navigationSplitViewColumnWidth(min: 250, ideal: 320)
            #endif
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem(placement: .bottomBar) {
                        filterContextMenu
                    }
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: addServer) {
                            Label("Add Server", systemImage: "plus")
                        }
                    }
                #elseif os(macOS)
                    ToolbarItem(placement: .automatic) {
                        Button(action: refreshAllServers) {
                            Label("Refresh All Servers", systemImage: "arrow.trianglehead.2.clockwise")
                        }
                    }

                    ToolbarItem(placement: .automatic) {
                        filterContextMenu
                    }
                    ToolbarItem(placement: .automatic) {
                        Button(action: addServer) {
                            Label("Add Server", systemImage: "plus")
                        }
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
        .onAppear {
            refreshAllServers()
        }
    }

    private var filterContextMenu: some View {
        Menu {
            ForEach(FilterMode.allCases, id: \.self) { mode in
                Button(action: {
                    filterMode = mode
                }) {
                    HStack {
                        Text(mode.rawValue)
                        if filterMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Group {
                if filterMode == .all {
                    Label("Filter Servers", systemImage: "line.3.horizontal.decrease")
                } else {
                    Label("Filter Servers", systemImage: "line.3.horizontal.decrease.circle.fill")
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .menuStyle(.button)
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
