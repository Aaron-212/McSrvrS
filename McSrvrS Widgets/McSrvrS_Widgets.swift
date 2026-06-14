import SwiftData
import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
    typealias Intent = ConfigurationAppIntent
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            server: .placeholder,
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> SimpleEntry {
        let server = await fetchSnapshot(
            for: configuration.server?.id
        )
        return SimpleEntry(
            date: Date(),
            server: server ?? .placeholder,
        )
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<SimpleEntry> {
        let server = await fetchSnapshot(
            for: configuration.server?.id
        )
        let entry = SimpleEntry(
            date: Date(),
            server: server ?? .placeholder,
        )

        return Timeline(entries: [entry], policy: .never)
    }

    func fetchSnapshot(for identifier: SelectedServerEntity.ID?) async -> ServerSnapshot? {
        guard let identifier else { return nil }

        let container = WidgetModelContainer.shared
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Server>(
            predicate: #Predicate { $0.id == identifier }
        )

        let server = try? context.fetch(descriptor).first
        return server.map(ServerSnapshot.init(server:))
    }
}

struct SimpleEntry: TimelineEntry {
    var date: Date
    var server: ServerSnapshot
}

struct ServerSnapshot {
    var id: UUID
    var name: String
    var address: String
    var lastUpdatedDate: Date
    var currentState: ServerStatus.StatusState

    init(
        id: UUID,
        name: String,
        address: String,
        lastUpdatedDate: Date,
        currentState: ServerStatus.StatusState
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.lastUpdatedDate = lastUpdatedDate
        self.currentState = currentState
    }

    init(server: Server) {
        self.init(
            id: server.id,
            name: server.name,
            address: server.address,
            lastUpdatedDate: server.lastUpdatedDate,
            currentState: server.currentState
        )
    }

    static var placeholder: ServerSnapshot {
        ServerSnapshot(
            id: UUID(),
            name: "Example Server",
            address: "example.com",
            lastUpdatedDate: .now,
            currentState: .loading
        )
    }

    var faviconImage: Image {
        currentState.faviconImage
    }
}

private enum ServerDeepLink {
    private static let scheme = "mcsrvrs"
    private static let serverHost = "server"

    static func url(for serverID: UUID?) -> URL? {
        if let serverID {
            URL(string: "\(scheme)://\(serverHost)/\(serverID.uuidString)")
        } else {
            nil
        }
    }
}

struct McSrvrS_WidgetsEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        ServerItemWidgetView(server: entry.server)
            .widgetURL(ServerDeepLink.url(for: entry.server.id))
    }
}

struct ServerItemWidgetView: View {
    @Environment(\.widgetFamily) private var sizeFamily
    let server: ServerSnapshot

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                server.faviconImage
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.containerRelative)

                Text(server.name)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(server.lastUpdatedDate.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Group {
                    switch server.currentState {
                    case .loading:
                        Text("Loading")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                    case .success(let status):
                        OnlineDisplayView(statusData: status)
                            .font(.callout)
                            .lineLimit(1)

                    case .error(_):
                        Text("Offline")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if sizeFamily == .systemMedium {
                switch server.currentState {
                case .loading:
                    Text("Loading server status")

                case .success(let status):
                    OnlinePlayersView(statusData: status)

                case .error(let message):
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct OnlinePlayersView: View {
    let statusData: ServerStatus.StatusData

    var body: some View {
        if let samples = statusData.players?.sample {
            VStack(alignment: .trailing) {
                Text("Online")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(samples.prefix(3), id: \.playerId) { player in
                    Text(player.name)
                        .font(.callout)
                        .lineLimit(1)
                }
            }
        } else {
            Text("No player samples available.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 110, alignment: .leading)
        }
    }
}

private struct OnlineDisplayView: View {
    let statusData: ServerStatus.StatusData

    var body: some View {
        VStack {
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

struct McSrvrS_Widgets: Widget {
    let kind: String = "McSrvrS_Widgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            McSrvrS_WidgetsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension ServerSnapshot {
    static var previewOnline: ServerSnapshot {
        preview(
            name: "Survival Realm",
            lastUpdatedDate: Date.now.addingTimeInterval(-45),
            state: .success(.previewOnline)
        )
    }

    static var previewOffline: ServerSnapshot {
        preview(
            name: "Creative Build",
            lastUpdatedDate: Date.now.addingTimeInterval(-8 * 60),
            state: .error("Connection timed out")
        )
    }

    static var previewLoading: ServerSnapshot {
        ServerSnapshot(
            id: UUID(),
            name: "Minigames Hub",
            address: "minigames.hello",
            lastUpdatedDate: Date.now.addingTimeInterval(-15),
            currentState: .loading
        )
    }

    static func preview(
        name: String,
        lastUpdatedDate: Date,
        state: ServerStatus.StatusState
    ) -> ServerSnapshot {
        ServerSnapshot(
            id: UUID(),
            name: name,
            address: "example.com",
            lastUpdatedDate: lastUpdatedDate,
            currentState: state
        )
    }
}

private extension ServerStatus.StatusData {
    static var previewOnline: ServerStatus.StatusData {
        ServerStatus.StatusData(
            version: ServerStatus.Version(name: "1.21.6", protocol: 770),
            players: ServerStatus.Players(
                max: 80,
                online: 12,
                sample: [
                    ServerStatus.Player(
                        name: "Alex",
                        playerId: "ec561538-f3fd-461d-aff5-086b22154bce"
                    ),
                    ServerStatus.Player(
                        name: "Steve",
                        playerId: "8667ba71-b85a-4004-af54-457a9734eed7"
                    ),
                    ServerStatus.Player(
                        name: "Builder212",
                        playerId: "00000000-0000-0000-0000-000000000000"
                    ),
                ]
            ),
            motd: "A preview Minecraft server",
            favicon: nil,
            latency: 42
        )
    }
}

#Preview("Online Small", as: .systemSmall) {
    McSrvrS_Widgets()
} timeline: {
    SimpleEntry(date: .now, server: .previewOnline)
}

#Preview("Online Medium", as: .systemMedium) {
    McSrvrS_Widgets()
} timeline: {
    SimpleEntry(date: .now, server: .previewOnline)
}

#Preview("Offline Medium", as: .systemMedium) {
    McSrvrS_Widgets()
} timeline: {
    SimpleEntry(date: .now, server: .previewOffline)
}

#Preview("Loading Small", as: .systemSmall) {
    McSrvrS_Widgets()
} timeline: {
    SimpleEntry(date: .now, server: .previewLoading)
}
