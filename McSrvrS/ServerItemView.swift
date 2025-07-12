import SwiftUI

struct ServerItemView: View {
    var server: Server

    var body: some View {
        HStack {
            // Server Icon
            Group {
                if case .success(let status) = server.serverState,
                   let favicon = status.decodeBase64PNG {
                    favicon
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image("pack")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            VStack(alignment: .leading) {
                HStack {
                    Text(server.name)
                        .bold()
                    Spacer()
                    Text(server.lastUpdatedDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)

                Group {
                    switch server.serverState {
                    case .success(let status):
                        HStack {
                            Group {
                                Image(systemName: "cellularbars", variableValue: status.latencyVariableColor)
                                Text(status.latencyDescription)
                            }
                            Group {
                                Image(systemName: "person.2.fill")
                                Text(status.playersDescription)
                            }
                        }
                        .font(.callout)
                        Text(status.motd)
                            .lineLimit(1)
                            .font(.footnote)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    case .error(_):
                        Group {
                            Image(systemName: "xmark.circle.fill")
                            Text("Unable to fetch server status")
                        }
                            .font(.callout)
                        Group {
                            if let lastSeenDate = server.lastSeenDate {
                                Text("Last seen at \(lastSeenDate.formatted(date: .abbreviated, time: .shortened))")
                            } else {
                                Text("Never seen")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    case .loading:
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                }
            }
        }
    }
}

#Preview {
    let server = Server(name: "Example Server", host: "example.com", port: 25565)
    ServerItemView(server: server)
}
