import SwiftUI

struct ServerItemView: View {
    var server: Server

    var body: some View {
        HStack {
            server.faviconImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading) {
                HStack {
                    Text(server.name)
                        .bold()
                    Spacer()
                    TimelineView(.periodic(from: server.lastUpdatedDate, by: 60)) { _ in
                        Text(server.lastUpdatedDate.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)

                Group {
                    switch server.currentState {
                    case .success(let statusData):
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "cellularbars", variableValue: statusData.variableColor)
                                if let latency = statusData.latency {
                                    Text(verbatim: "\(latency) ms")
                                } else {
                                    Text(verbatim: "N/A")
                                }
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                if let players = statusData.players {
                                    Text(players.online, format: .number)
                                    Text(verbatim: "/")
                                    Text(players.max, format: .number)
                                } else {
                                    Text(verbatim: "???")
                                }
                            }
                        }
                        .lineLimit(1)
                        .font(.callout)
                        if let motd = statusData.parseMotd(skipColor: true, trimWhitespace: true) {
                            Text(motd)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                        }
                    case .error(_):
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Unable to fetch server status")
                        }
                        .lineLimit(1)
                        .font(.callout)
                        Group {
                            if let lastSeenDate = server.lastSeenDate {
                                Text("Last seen at \(lastSeenDate.formatted(date: .abbreviated, time: .shortened))")
                            } else {
                                Text("Never seen online")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    case .loading:
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                }
            }
        }
        #if os(macOS)
            .padding(.vertical, 4)
        #endif
    }
}

extension ServerStatus.StatusData {
    var variableColor: Double {
        if let latency = self.latency {
            switch latency {
            case ..<50:
                return 1.0
            case 50..<1000:
                return (Double(latency) - 150) / 850
            default:
                return 0.0
            }
        } else {
            return 0.0
        }
    }
}

#Preview {
    let server = Server(name: "Example Server", address: "example.com:25565", orderIndex: 0)
    ServerItemView(server: server)
}
