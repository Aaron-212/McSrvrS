import SwiftUI

struct ServerDetailView: View {
    let server: Server
    @State private var showingEditForm = false
    @State private var selectedSpan: QuerySpan = .last30Days

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Section
                ServerDetailHeaderSection(server: server)

                // Server Status Section
                ServerDetailStatusSection(server: server)

                // Players Section (if available)
                if case .success(let statusData) = server.currentState {
                    ServerDetailPlayersSection(statusData: statusData)
                }

                // Players Chart Section
                ServerDetailPlayersChartSection(server: server, selectedSpan: $selectedSpan)

                // Connection History Section
                ServerDetailConnectionHistorySection(server: server)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .toolbar {
            #if os(macOS)
                ToolbarItem {
                    Button(action: refreshServer) {
                        Label("Refresh", systemImage: "arrow.trianglehead.clockwise")
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
            ServerForm(serverToEdit: server)
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
    let server = Server(name: "Example Server", host: "mc.example.com", port: 25565)
    NavigationView {
        ServerDetailView(server: server)
    }
}
