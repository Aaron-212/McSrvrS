import SwiftUI

struct ServerDetailView: View {
    let server: Server
    @State private var showingEditForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Section
                headerSection

                // Server Status Section
                serverStatusSection

                // Players Section (if available)
                if case .success(let status) = server.serverState {
                    playersSection(status: status)
                }

                // Connection History Section
                connectionHistorySection
            }
            .padding()
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
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            server.faviconView
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading) {
                Text(server.name)
                    .font(.title2)
                    .bold()

                Text(server.addressDescription)
                    .font(.subheadline)
                    .fontDesign(.monospaced)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var serverStatusSection: some View {
        GroupBox(label: Label("Server Status", systemImage: "server.rack")) {
            switch server.serverState {
            case .success(let status):
                VStack(alignment: .leading) {
                    Text(status.motd.isEmpty ? "No MOTD available" : status.parseMotd())
                        .padding(.vertical)

                    LabeledContent(
                        "Latency",
                        value: status.latencyDescription
                    )
                    LabeledContent(
                        "Version",
                        value: status.version.name
                    )
                }

            case .error(_):
                Label("Connection Failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding()

            case .loading:
                VStack(alignment: .leading) {
                    Text("Checking server status...")
                        .font(.body)
                        .foregroundColor(.secondary)
                    ProgressView()
                        .progressViewStyle(.linear)

                }
            }
        }
    }

    private var connectionHistorySection: some View {
        GroupBox(label: Label("Connection History", systemImage: "clock.arrow.circlepath")) {
            VStack {
                if let lastSeenDate = server.lastSeenDate {
                    VStack(alignment: .leading) {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .shadow(color: Color.green.opacity(0.3), radius: 2, x: 0, y: 1)

                            Text("Connected")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)

                            Spacer()
                        }

                        Text("Last successful connection: \(lastSeenDate, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading) {
                        HStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 12, height: 12)
                                .shadow(color: Color.orange.opacity(0.3), radius: 2, x: 0, y: 1)

                            Text("Never Connected")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)

                            Spacer()
                        }

                        Text("This server has never been successfully reached")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                LabeledContent(
                    "Last Updated",
                    value: server.lastUpdatedDate.formatted(date: .abbreviated, time: .shortened)
                )
                if let lastSeenDate = server.lastSeenDate {
                    LabeledContent(
                        "Last Seen Online",
                        value: lastSeenDate.formatted(date: .abbreviated, time: .shortened)
                    )
                } else {
                    LabeledContent("Last Seen Online", value: "Never")
                }
            }
        }
    }

    @ViewBuilder
    private func playersSection(status: Server.Status) -> some View {
        GroupBox(
            label:
                HStack {
                    Label("Players", systemImage: "person.2.fill")
                    Spacer()
                    Text("\(status.players.online) / \(status.players.max)")
                }
        ) {
            if let playerSample = status.players.sample, !playerSample.isEmpty {
                Divider()
                LazyVStack(alignment: .leading) {
                    ForEach(playerSample, id: \.id) { player in
                        HStack {
                            AsyncImage(url: player.avatarUrl) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 32, height: 32)
                                case .failure:
                                    Image("Steve")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 32, height: 32)
                                default:
                                    ProgressView()
                                        .frame(width: 32, height: 32)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(player.name)
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                    }
                }

                if status.players.online > status.players.sample?.count ?? 0 {
                    Text("and \(status.players.online - UInt32(playerSample.count)) more...")
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            } else if status.players.online > 0 {
                Text("Player list not available")
                    .foregroundColor(.secondary)
                    .padding(16)
            } else {
                Text("No players currently online")
                    .foregroundColor(.secondary)
                    .padding(16)
            }
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch server.serverState {
        case .success:
            return .green
        case .error:
            return .red
        case .loading:
            return .orange
        }
    }

    private var statusText: String {
        switch server.serverState {
        case .success:
            return "Online"
        case .error:
            return "Offline"
        case .loading:
            return "Checking..."
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
