import SwiftUI

struct ServerDetailStatusSection: View {
    let server: Server

    var body: some View {
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
                switch server.currentState {
                case .success(let statusData):
                    if let motd = statusData.parseMotd() {
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
                                if let latency = statusData.latency {
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

                            Text(statusData.version.name.trimmingFormatCodes())
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

    private var statusColor: Color {
        switch server.currentState {
        case .success:
            return .green
        case .error:
            // Never connected: red, Previously connected but can't connect now: orange
            return server.lastSeenDate == nil ? .red : .orange
        case .loading:
            return .orange
        }
    }

    private var connectionStatusColor: Color {
        switch server.currentState {
        case .success:
            return .green
        case .error:
            return server.lastSeenDate == nil ? .red : .orange
        case .loading:
            return .accent
        }
    }

    private var connectionStatusTitle: String {
        switch server.currentState {
        case .success:
            return "Connected"
        case .error:
            return server.lastSeenDate == nil ? "Never Connected" : "Connection Lost"
        case .loading:
            return "Checking..."
        }
    }
}
