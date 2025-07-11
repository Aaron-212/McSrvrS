import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var servers: [Server]
    @State private var searchText = ""
    @State private var showingServerForm = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(servers) { server in
                    NavigationLink {
                        Text("Server")
                    } label: {
                        ServerItemView(server: server)
                    }
                }
                .onDelete(perform: deleteItems)
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
                #endif
                ToolbarItem(placement: .automatic) {
                    Button(action: addItem) {
                        Label("Add Server", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $searchText)
            .refreshable {
                // Implement refresh logic if needed
            }
        } detail: {
            Text("Select an item")
        }
        .sheet(isPresented: $showingServerForm) {
            ServerForm()
        }
    }

    private func addItem() {
        showingServerForm = true
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(servers[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Server.self, inMemory: true)
}
