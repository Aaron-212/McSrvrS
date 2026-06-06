#if os(macOS)
import SwiftData
import SwiftUI

struct MenuBarServerListView: View {
    @Query(sort: \Server.orderIndex) private var servers: [Server]

    private var displayedServers: [Server] {
        Array(servers.prefix(3))
    }

    var body: some View {
        List {
            if displayedServers.isEmpty {
                ContentUnavailableView {
                    Label("No Servers", systemImage: "server.rack")
                } description: {
                    Text("Add servers in the main window to see them here.")
                }
                .frame(width: 320, height: 180)
            } else {
                ForEach(displayedServers) { server in
                    ServerItemView(server: server)
                }
            }

            HStack {
                Button {
                    //
                } label: {
                    Text("Open main window")
                }
            }
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Server.self, ServerStatus.self, configurations: configuration)

    let servers = [
        Server(name: "Survival", host: "survival.example.com", port: 25565, orderIndex: 0),
        Server(name: "Creative", host: "creative.example.com", port: 25565, orderIndex: 1),
        Server(name: "Minigames", host: "mini.example.com", port: 25565, orderIndex: 2),
    ]

    for server in servers {
        container.mainContext.insert(server)
    }

    return MenuBarServerListView()
        .modelContainer(container)
}
#endif
