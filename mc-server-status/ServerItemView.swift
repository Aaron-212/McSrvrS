import SwiftUI

struct ServerItemView: View {
    var server: Server

    var body: some View {
        HStack {
            // Server Icon placegholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    switch server.state {
                    case .online:
                        HStack {
                            Group {
                                Image(systemName: "cellularbars", variableValue: 0.75)
                                Text("20 ms")
                            }
                            Group {
                                Image(systemName: "person.2.fill")
                                Text("0 / 2")
                            }
                        }
                        .font(.callout)
                        Text("Server description possibly multiline but whatever you want to put here")
                            .lineLimit(1)
                            .font(.footnote)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    case .offline:
                        Label("Offline", systemImage: "xmark.octagon.fill")
                            .font(.callout)
                        Text("Last seen at \(server.lastSeenDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    case .pinging:
                        ProgressView()
                    case .unknown:
                        Text("Unknown")
                    }
                }
            }
        }
    }
}

#Preview {
    let server = Server(name: "Example Server", domain: "example.com", port: 25565)
    ServerItemView(server: server)
}
