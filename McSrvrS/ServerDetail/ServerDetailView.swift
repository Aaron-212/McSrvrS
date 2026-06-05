import SwiftUI

struct ServerDetailView: View {
    let server: Server
    @State private var showingEditForm = false
    @State private var selectedHistorySpan: PlayerHistorySpan = .lastMonth

    var body: some View {
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
        .toolbar {
            #if os(macOS)
                ToolbarItem {
                    Button(action: refreshServer) {
                        Label("Refresh This Server", systemImage: "arrow.trianglehead.clockwise")
                    }
                }
            #endif
            ToolbarItem {
                Button(action: { showingEditForm = true }) {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .refreshable {
            refreshServer()
        }
        .sheet(isPresented: $showingEditForm) {
            ServerForm(editingServer: server)
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshThisServer)) { _ in
            refreshServer()
        }
    }

    // MARK: - Actions

    private func refreshServer() {
        Task {
            await server.updateStatus()
        }
    }
}

#Preview {
    let server = Server(name: "Example Server", host: "mc.example.com", port: 25565, orderIndex: 0)
    NavigationView {
        ServerDetailView(server: server)
    }
}
