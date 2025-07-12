import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var servers: [Server]
    @State private var searchText = ""
    @State private var showingServerForm = false
    @State private var isFilteringServer = false
    @State private var showingServerFilter = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(servers) { server in
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
                    }
                }
                .onDelete(perform: deleteServers)
            }
            .listStyle(.plain)
            .navigationTitle("MC Server Status")
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
                #elseif os(macOS)
                    ToolbarItem(placement: .automatic) {
                        Button(action: refreshAllServers) {
                            Label("Refresh All Servers", systemImage: "arrow.trianglehead.2.clockwise")
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        filterContextMenu
                    }
                #endif
                ToolbarItem(placement: .automatic) {
                    Button(action: addServer) {
                        Label("Add Server", systemImage: "plus")
                    }
                }
            }
            .refreshable {
                refreshAllServers()
            }
        } detail: {
            Text("Select a Server")
                .font(.title)
                .foregroundStyle(.tertiary)
                .bold()
        }
        .searchable(text: $searchText, prompt: "Search Servers")
        .sheet(isPresented: $showingServerForm) {
            ServerForm()
        }
        .onAppear {
            refreshAllServers()
        }
    }

    private var filterContextMenu: Menu = Menu {
        Text("hello")
    } label: {
        Label("Filter Servers", systemImage: "line.3.horizontal.decrease")
    }

    private func addServer() {
        showingServerForm = true
    }

    private func serverFilter() {
        isFilteringServer = true
    }

    private func deleteServers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(servers[index])
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
