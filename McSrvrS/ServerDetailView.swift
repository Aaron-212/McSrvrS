import CachedAsyncImage
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
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical)
    }

    private var serverStatusSection: some View {
        SectionView {
            HStack {
                Label("Server Status", systemImage: "server.rack")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Label(connectionStatusTitle, systemImage: "circle.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(connectionStatusColor)
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                switch server.serverState {
                case .success(let status):
                    if let motd = status.parseMotd() {
                        MotdView(motd: motd)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latency")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Group {
                                if let latency = status.latency {
                                    Text(verbatim: "\(latency) ms")
                                } else {
                                    Text("N/A")
                                }
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Version")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Text(status.version.name.trimmingFormatCodes())
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }

                case .error(let error):
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(statusColor)

                        Text("Connection Failed")
                            .font(.headline)
                            .foregroundStyle(statusColor)

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                case .loading:
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("Checking server status...")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
    }

    private var connectionHistorySection: some View {
        SectionView {
            HStack {
                Label("Connection History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)

                Spacer()
            }
        } content: {
            VStack(spacing: 16) {
                HStack {
                    Label(connectionStatusTitle, systemImage: "circle.fill")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(connectionStatusColor)

                    Spacer()
                }

                VStack(spacing: 8) {
                    HStack {
                        Text("Last Updated")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        Text(server.lastUpdatedDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }

                    HStack {
                        Text("Last Seen Online")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        if let lastSeenDate = server.lastSeenDate {
                            Text(lastSeenDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.callout)
                        } else {
                            Text("Never")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func playersSection(status: Server.Status) -> some View {
        SectionView {
            HStack {
                Label("Players", systemImage: "person.2.fill")
                    .font(.headline)

                Spacer()

                Group {
                    if let players = status.players {
                        Text("\(players.online) / \(players.max)")
                    } else {
                        Text(verbatim: "???")
                    }
                }
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            }
        } content: {
            VStack(spacing: 12) {
                if let players = status.players, let playerSample = players.sample, !playerSample.isEmpty {
                    LazyVStack(spacing: 12) {
                        ForEach(playerSample, id: \.id) { player in
                            PlayerItemView(player: player)
                        }
                    }

                    if players.online > players.sample?.count ?? 0 {
                        Text("and \(players.online - UInt32(playerSample.count)) more...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                } else if let players = status.players, players.online > 0 {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("Player list not available")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("No players currently online")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
    }

    // MARK: - Custom Views

    private struct MotdView: View {
        @Environment(\.colorScheme) var colorScheme

        let motd: AttributedString

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Message of the Day")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(motd)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .colorScheme(.dark)
            }
            .padding(.bottom, 8)
        }
    }

    private struct PlayerItemView: View {
        let player: Server.Player

        var body: some View {
            HStack(spacing: 12) {
                CachedAsyncImage(url: player.avatarUrl) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image("Steve")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 32, height: 32)

                Text(player.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .textSelection(.enabled)

                Spacer()
            }
        }
    }

    private struct SectionView<Header: View, Content: View>: View {
        let header: Header
        let content: Content

        init(
            @ViewBuilder header: () -> Header,
            @ViewBuilder content: () -> Content
        ) {
            self.header = header()
            self.content = content()
        }

        var body: some View {
            VStack(spacing: 0) {
                header
                Divider()
                    .padding(.vertical)
                content
            }
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch server.serverState {
        case .success:
            return .green
        case .error:
            // Never connected: red, Previously connected but can't connect now: orange
            return server.lastSeenDate == nil ? .red : .orange
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

    private var connectionStatusColor: Color {
        switch server.serverState {
        case .success:
            return .green
        case .error:
            return server.lastSeenDate == nil ? .red : .orange
        case .loading:
            return .accent
        }
    }

    private var connectionStatusTitle: String {
        switch server.serverState {
        case .success:
            return "Connected"
        case .error:
            return server.lastSeenDate == nil ? "Never Connected" : "Connection Lost"
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
