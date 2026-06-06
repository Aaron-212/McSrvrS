import Foundation
import SwiftUI

struct ServerListFilter: Equatable {
    var searchText: String
    var showsOnlineOnly: Bool

    func apply(to servers: [Server]) -> [Server] {
        let matchingServers =
            searchText.isEmpty
            ? servers
            : servers.filter { server in
                server.name.localizedCaseInsensitiveContains(searchText)
                    || server.addressDescription.localizedCaseInsensitiveContains(searchText)
            }

        guard showsOnlineOnly else {
            return matchingServers
        }

        return matchingServers.filter(\.isOnline)
    }

    func unavailableContentTitle(hasServers: Bool) -> LocalizedStringResource {
        if !hasServers {
            return "No Servers Added"
        } else if showsOnlineOnly && !searchText.isEmpty {
            return "No Results"
        } else if showsOnlineOnly {
            return "No Online Servers"
        } else {
            return "No Results"
        }
    }

    func unavailableContentDescription(hasServers: Bool) -> LocalizedStringResource {
        if !hasServers {
            return "Add your first Minecraft server to get started"
        } else if showsOnlineOnly && !searchText.isEmpty {
            return "No online servers matching \"\(searchText)\""
        } else if showsOnlineOnly {
            return "All servers are currently offline"
        } else {
            return "No servers matching \"\(searchText)\""
        }
    }
}

enum ServerListOrdering {
    static func reorderedServers(
        all servers: [Server],
        visibleServers: [Server],
        source: IndexSet,
        destination: Int
    ) -> [Server] {
        var reorderedVisibleServers = visibleServers
        reorderedVisibleServers.move(fromOffsets: source, toOffset: destination)

        let visibleServerIDs = Set(visibleServers.map(\.id))
        var visibleServerIterator = reorderedVisibleServers.makeIterator()

        return servers.map { server in
            visibleServerIDs.contains(server.id)
                ? (visibleServerIterator.next() ?? server)
                : server
        }
    }
}
