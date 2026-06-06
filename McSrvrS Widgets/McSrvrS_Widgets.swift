import SwiftData
import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: ConfigurationAppIntent(),
            server: Server.placeholder,
            loadError: nil
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        if context.isPreview {
            return SimpleEntry(
                date: Date(),
                configuration: configuration,
                server: Server.placeholder,
                loadError: nil
            )
        }

        let selection = await WidgetServerStore.selection(
            selectedServerID: configuration.server?.uuid
        )
        return SimpleEntry(
            date: Date(),
            configuration: configuration,
            server: selection.server,
            loadError: selection.errorMessage
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let selection = await WidgetServerStore.selection(
            selectedServerID: configuration.server?.uuid
        )
        let entry = SimpleEntry(
            date: Date(),
            configuration: configuration,
            server: selection.server,
            loadError: selection.errorMessage
        )
        let nextReloadDate = Date().addingTimeInterval(15 * 60)

        return Timeline(entries: [entry], policy: .after(nextReloadDate))
    }
}

extension Server {
    static var placeholder: Server {
        return Server(name: "Example Server", address: "play.example.net", orderIndex: 1)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let server: Server?
    let loadError: String?
}

struct WidgetServerSelection {
    let server: Server?
    let servers: [Server]
    let errorMessage: String?
}

@MainActor
enum WidgetServerStore {
    private static let modelContainerResult: Result<ModelContainer, Error> = Result {
        try AppModelContainer.make(allowsSave: false)
    }

    static func selection(selectedServerID: UUID? = nil) -> WidgetServerSelection {
        do {
            let container = try modelContainerResult.get()
            let context = container.mainContext
            let descriptor = FetchDescriptor<Server>(
                sortBy: [
                    SortDescriptor(\.orderIndex),
                    SortDescriptor(\.name),
                ]
            )
            let servers = try context.fetch(descriptor)
            let selectedServer =
                selectedServerID.flatMap { selectedServerID in
                    servers.first { $0.id == selectedServerID }
                } ?? servers.first

            return WidgetServerSelection(
                server: selectedServer,
                servers: servers,
                errorMessage: nil
            )
        } catch {
            return WidgetServerSelection(
                server: nil,
                servers: [],
                errorMessage: "Could not load servers"
            )
        }
    }
}

struct McSrvrS_WidgetsEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        HStack {
            if let loadError = entry.loadError {
                ContentUnavailableView(
                    "Unavailable",
                    systemImage: "externaldrive.badge.xmark",
                    description: Text(loadError)
                )
            } else if let server = entry.server {
                ServerItemWidgetView(server: server)
            } else {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "server.rack",
                    description: Text("Add servers in McSrvrS")
                )
            }

            Spacer()
        }
    }
}

struct ServerItemWidgetView: View {
    let server: Server

    var body: some View {
        VStack(alignment: .leading) {
            server.faviconImage
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .aspectRatio(contentMode: server.hasCustomFavicon ? .fit : .fill)
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
                    onlineDisplay(status)
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
    }

    private func onlineDisplay(_ statusData: ServerStatus.StatusData) -> some View {
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
        .supportedFamilies([.systemSmall])
    }
}
