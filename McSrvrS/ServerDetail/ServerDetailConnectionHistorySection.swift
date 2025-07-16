import SwiftUI

struct ServerDetailConnectionHistorySection: View {
    let server: Server

    var body: some View {
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

                        Text(server.lastUpdatedDate.formatted(date: .abbreviated, time: .standard))
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
                            Text(lastSeenDate.formatted(date: .abbreviated, time: .standard))
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
