import SwiftData
import SwiftUI

struct ServerDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let serverID: Server.ID
    @Query private var servers: [Server]

    @State private var presentedEditingSheet: Bool = false
    @State private var selectedHistorySpan: PlayerHistorySpan = .lastMonth

    private var server: Server? {
        servers.first
    }

    init(serverID: Server.ID) {
        self.serverID = serverID
        _servers = Query(
            filter: #Predicate { server in
                server.id == serverID
            }
        )
    }

    var body: some View {
        if let server {
            serverDetailContent(for: server)
        } else {
            ContentUnavailableView {
                Label("Server Not Found", systemImage: "server.rack")
            } description: {
                Text("The selected server may have been deleted.")
            }
        }
    }

    private func serverDetailContent(for server: Server) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ServerDetailHeaderSection(server: server)

                ServerDetailStatusSection(server: server)

                if case .success(let statusData) = server.currentState {
                    ServerDetailPlayersSection(statusData: statusData)
                }

                ServerDetailPlayersChartSection(
                    server: server,
                    selectedSpan: $selectedHistorySpan
                )

                ServerDetailConnectionHistorySection(server: server)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        #if os(macOS)
            .navigationTitle(server.name)
        #endif
        .toolbar {
            #if os(macOS)
                if #unavailable(anyAppleOS 26) {
                    ToolbarItem {
                        Button {
                            Task {
                                await ServerRefreshService.refresh(
                                    serverID,
                                    modelContainer: modelContext.container
                                )
                            }
                        } label: {
                            Label(
                                "Refresh This Server",
                                systemImage: "arrow.trianglehead.clockwise"
                            )
                        }
                    }
                }
            #endif
            ToolbarItem {
                Button(action: { presentedEditingSheet = true }) {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .refreshable {
            await ServerRefreshService.refresh(
                serverID,
                modelContainer: modelContext.container
            )
        }
        .sheet(isPresented: $presentedEditingSheet) {
            ServerForm(editingServer: server)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .refreshThisServer)
        ) { _ in
            Task {
                await ServerRefreshService.refresh(
                    serverID,
                    modelContainer: modelContext.container
                )
            }
        }
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Server.self, ServerStatus.self, configurations: configuration)
    let server = Server(
        name: "Example Server",
        address: "mc.example.com",
        orderIndex: 0
    )
    container.mainContext.insert(server)

    return NavigationStack {
        ServerDetailView(serverID: server.id)
    }
    .modelContainer(container)
}
