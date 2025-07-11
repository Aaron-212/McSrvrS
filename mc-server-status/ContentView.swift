import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var servers: [Server]
    @State private var searchText = ""
    @State private var showingServerForm = false
    @State private var pinger = ServerPinger()

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
                                await server.updateStatus(using: pinger)
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
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            #endif
            .toolbar {
                #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                #elseif os(macOS)
                    ToolbarItem(placement: .automatic) {
                        Button(action: refreshAllServers) {
                            Label("Refresh All", systemImage: "arrow.clockwise")
                        }
                    }
                #endif
                ToolbarItem(placement: .automatic) {
                    Button(action: addServer) {
                        Label("Add Server", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $searchText)
            .refreshable {
                refreshAllServers()
            }
        } detail: {
            Text("Select an item")
        }
        .sheet(isPresented: $showingServerForm) {
            ServerForm()
        }
        .onAppear {
            refreshAllServers()
        }
    }

    private func addServer() {
        showingServerForm = true
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
                        await server.updateStatus(using: pinger)
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
