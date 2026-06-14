import Foundation
import Testing

@testable import McSrvrS

struct ServerListLogicTests {
    @Test func filterMatchesNameAndAddressCaseInsensitively() {
        let alpha = Server(name: "Alpha", address: "alpha.example.net", orderIndex: 0)
        let beta = Server(name: "Beta", address: "play.beta.net", orderIndex: 1)
        let servers = [alpha, beta]

        let alphaMatches = ServerListFilter(searchText: "alp", showsOnlineOnly: false)
            .apply(to: servers)
        let betaMatches = ServerListFilter(searchText: "BETA.NET", showsOnlineOnly: false)
            .apply(to: servers)

        #expect(alphaMatches.map(\.id) == [alpha.id])
        #expect(betaMatches.map(\.id) == [beta.id])
    }

    @Test func filterCanShowOnlineServersOnly() {
        let online = Server(name: "Online", address: "online.example.net", orderIndex: 0)
        let offline = Server(name: "Offline", address: "offline.example.net", orderIndex: 1)
        online.statuses = [ServerStatus(server: online, state: .success(Self.statusData()))]
        offline.statuses = [ServerStatus(server: offline, state: .error("offline"))]

        let filtered = ServerListFilter(searchText: "", showsOnlineOnly: true)
            .apply(to: [online, offline])

        #expect(filtered.map(\.id) == [online.id])
    }

    @Test func reordersVisibleSubsetWithoutMovingHiddenServers() {
        let first = Server(name: "First", address: "first.example.net", orderIndex: 0)
        let hidden = Server(name: "Hidden", address: "hidden.example.net", orderIndex: 1)
        let second = Server(name: "Second", address: "second.example.net", orderIndex: 2)
        let third = Server(name: "Third", address: "third.example.net", orderIndex: 3)

        let reordered = ServerListOrdering.reorderedServers(
            all: [first, hidden, second, third],
            visibleServers: [first, second, third],
            source: IndexSet(integer: 2),
            destination: 0
        )

        #expect(reordered.map(\.id) == [third.id, hidden.id, first.id, second.id])
    }

    private static func statusData() -> ServerStatus.StatusData {
        ServerStatus.StatusData(
            version: .init(name: "Test Version", protocol: 765),
            players: nil,
            motd: nil,
            favicon: nil,
            latency: nil
        )
    }
}
