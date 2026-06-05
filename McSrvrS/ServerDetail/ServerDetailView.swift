import SwiftUI

struct ServerDetailView: View {
    let server: Server
    @State private var presentedSheet: ServerDetailSheet?
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
        #if os(macOS)
            .navigationTitle(server.name)
        #endif
        .toolbar {
            #if os(macOS)
                ToolbarItem {
                    Button {
                        Task { await refreshServer() }
                    } label: {
                        Label("Refresh This Server", systemImage: "arrow.trianglehead.clockwise")
                    }
                }
            #endif
            ToolbarItem {
                Button(action: { presentedSheet = .edit }) {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .refreshable {
            await refreshServer()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .edit:
                ServerForm(editingServer: server)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshThisServer)) { _ in
            Task { await refreshServer() }
        }
    }

    // MARK: - Actions

    private func refreshServer() async {
        await ServerRefreshService.refresh(server)
    }
}

private enum ServerDetailSheet: Identifiable {
    case edit

    var id: String {
        "edit"
    }
}

#Preview {
    let server = Server(name: "Example Server", host: "mc.example.com", port: 25565, orderIndex: 0)
    NavigationStack {
        ServerDetailView(server: server)
    }
}
