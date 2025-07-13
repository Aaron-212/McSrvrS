import SwiftUI

struct ServerDetailView: View {
    let server: Server
    @State private var showingEditForm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
    }

    private var headerSection: some View {
        VStack {
            server.faviconView
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

            VStack(spacing: 4) {
                Text(server.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(server.addressDescription)
                    .font(.subheadline)
                    .fontDesign(.monospaced)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical)
    }

    private var serverStatusSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Label("Server Status", systemImage: "server.rack")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                }
            }
            .padding()

            // Content
            VStack(alignment: .leading, spacing: 12) {
                switch server.serverState {
                case .success(let status):
                    if !status.motd.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message of the Day")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text(status.parseMotd())
                                .font(.body)
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                        }
                        .padding(.bottom, 8)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latency")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text(status.latencyDescription)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Version")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text(status.version.name)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }

                case .error(_):
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.red)

                        Text("Connection Failed")
                            .font(.headline)
                            .foregroundColor(.red)

                        Text("Unable to connect to the server")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                case .loading:
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("Checking server status...")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var connectionHistorySection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Label("Connection History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Content
            VStack(spacing: 16) {
                if let lastSeenDate = server.lastSeenDate {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .shadow(color: Color.green.opacity(0.3), radius: 2, x: 0, y: 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)

                            Text("Last successful connection: \(lastSeenDate, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                } else {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                            .shadow(color: Color.orange.opacity(0.3), radius: 2, x: 0, y: 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Never Connected")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)

                            Text("This server has never been successfully reached")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }

                Divider()

                VStack(spacing: 8) {
                    HStack {
                        Text("Last Updated")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        Text(server.lastUpdatedDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.callout)
                            .foregroundColor(.primary)
                    }

                    HStack {
                        Text("Last Seen Online")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        if let lastSeenDate = server.lastSeenDate {
                            Text(lastSeenDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.callout)
                                .foregroundColor(.primary)
                        } else {
                            Text("Never")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func playersSection(status: Server.Status) -> some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Label("Players", systemImage: "person.2.fill")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text(status.playersDescription)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Content
            VStack(spacing: 12) {
                if let playerSample = status.players.sample, !playerSample.isEmpty {
                    LazyVStack(spacing: 12) {
                        ForEach(playerSample, id: \.id) { player in
                            HStack(spacing: 12) {
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
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                                Text(player.name)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                        }
                    }

                    if status.players.online > status.players.sample?.count ?? 0 {
                        Text("and \(status.players.online - UInt32(playerSample.count)) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                } else if status.players.online > 0 {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Text("Player list not available")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Text("No players currently online")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
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
