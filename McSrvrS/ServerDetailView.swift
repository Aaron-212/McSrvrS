import SwiftUI

struct ServerDetailView: View {
    let server: Server
    @State private var pinger = JavaServerPinger.shared
    @State private var showingEditForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Section
                headerSection

                // Status Section
                statusSection

                // Server Information Section
                serverInfoSection

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
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem {
                    Button(action: { showingEditForm = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            #elseif os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEditForm = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            #endif
        }
        .refreshable {
            refreshServer()
        }
        .sheet(isPresented: $showingEditForm) {
            ServerForm(serverToEdit: server)
        }
    }

    private var headerSection: some View {
        HStack {
            // Server Icon
            Group {
                if case .success(let status) = server.serverState,
                    let favicon = status.decodeBase64PNG
                {
                    favicon
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Image("pack")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .shadow(radius: 4)

            VStack(alignment: .leading) {
                Text(server.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(server.host):\(server.port)")
                    .font(.subheadline)
                    .fontDesign(.monospaced)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                // Status Indicator
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            Spacer()
        }
    }

    private var statusSection: some View {
        GroupBox {
            switch server.serverState {
            case .success(let status):
                VStack(alignment: .leading, spacing: 12) {
                    // Connection Stats
                    HStack {
                        Label {
                            Text(status.latencyDescription)
                        } icon: {
                            Image(systemName: "cellularbars", variableValue: status.latencyVariableColor)
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        Label {
                            Text(status.playersDescription)
                        } icon: {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.callout)

                    Divider()

                    // MOTD
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Message of the Day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Text(status.motd.isEmpty ? "No MOTD available" : status.motd)
                            .font(.body)
                            .fontDesign(.monospaced)
                            .lineLimit(nil)
                    }

                    Divider()

                    // Version Info
                    HStack {
                        Text("Version")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(status.version.name)
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                }

            case .error(let errorMessage):
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Connection Failed")
                            .font(.headline)
                    }

                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                }

            case .loading:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking server status...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        } label: {
            Text("Server Status")
                .font(.headline)
        }
    }

    private var serverInfoSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                InfoRow(label: "Host", value: server.host)
                InfoRow(label: "Port", value: String(server.port))
                InfoRow(
                    label: "Last Updated",
                    value: server.lastUpdatedDate.formatted(date: .abbreviated, time: .shortened)
                )

                if let lastSeenDate = server.lastSeenDate {
                    InfoRow(
                        label: "Last Seen Online",
                        value: lastSeenDate.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
        } label: {
            Text("Server Information")
                .font(.headline)
        }
    }

    @ViewBuilder
    private func playersSection(status: Server.Status) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Players Online")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(status.players.online) / \(status.players.max)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                if let playerSample = status.players.sample, !playerSample.isEmpty {
                    Divider()

                    List {
                        ForEach(playerSample, id: \.id) { player in
                            HStack {
                                AsyncImage(url: player.avatarUrl) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 32, height: 32)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
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

                                Text(player.name)
                                    .font(.callout)

                                Spacer()
                            }
                        }
                    }

                    if status.players.online > status.players.sample?.count ?? 0 {
                        Text("and \(status.players.online - UInt32(playerSample.count)) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else if status.players.online > 0 {
                    Text("Player list not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text("No players currently online")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        } label: {
            Text("Players")
                .font(.headline)
        }
    }

    private var connectionHistorySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if let lastSeenDate = server.lastSeenDate {
                    HStack {
                        Text("Connection Status")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text("Connected")
                            .foregroundColor(.green)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Text("Last successful connection: \(lastSeenDate, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack {
                        Text("Connection Status")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text("Never Connected")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Text("This server has never been successfully reached")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } label: {
            Text("Connection History")
                .font(.headline)
        }
    }

    // MARK: - Helper Views

    private struct InfoRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack {
                Text(label)
                    .font(.callout)
                    .foregroundColor(.secondary)

                Spacer()

                Text(value)
                    .font(.callout)
                    .fontWeight(.medium)
                    .textSelection(.enabled)
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
            await server.updateStatus(using: pinger)
        }
    }
}

#Preview {
    let server = Server(name: "Example Server", host: "mc.example.com", port: 25565)
    NavigationView {
        ServerDetailView(server: server)
    }
}
