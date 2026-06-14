import Foundation
import Testing

@testable import McSrvrS

struct ServerStatusModelTests {
    @Test func exposesStateConvenienceProperties() {
        let server = Server(name: "Test", address: "play.example.net", orderIndex: 0)
        let success = ServerStatus(server: server, state: .success(Self.statusData()))
        let error = ServerStatus(server: server, state: .error("offline"))
        let loading = ServerStatus(server: server, state: .loading)

        #expect(success.isSuccess)
        #expect(!success.isError)
        #expect(!success.isLoading)
        #expect(success.statusData?.version.name == "Test Version")
        #expect(success.errorMessage == nil)

        #expect(error.isError)
        #expect(error.errorMessage == "offline")
        #expect(error.statusData == nil)

        #expect(loading.isLoading)
    }

    @Test func serverUsesNewestStatusForCurrentState() {
        let server = Server(name: "Test", address: "play.example.net", orderIndex: 0)
        let older = ServerStatus(server: server, state: .error("old"))
        older.timestamp = Date(timeIntervalSince1970: 100)
        let newer = ServerStatus(server: server, state: .success(Self.statusData()))
        newer.timestamp = Date(timeIntervalSince1970: 200)
        server.statuses = [newer, older]

        #expect(server.latestStatus?.id == newer.id)
        #expect(server.isOnline)
    }

    @Test func playerAvatarUrlSkipsAnonymousPlayers() {
        let anonymous = ServerStatus.Player(
            name: "Anonymous",
            playerId: "00000000-0000-0000-0000-000000000000"
        )
        let named = ServerStatus.Player(
            name: "Alex",
            playerId: "11111111-2222-3333-4444-555555555555"
        )

        #expect(anonymous.avatarUrl == nil)
        #expect(
            named.avatarUrl?.absoluteString
                == "https://crafatar.com/avatar/11111111-2222-3333-4444-555555555555?size=64&overlay"
        )
    }

    private static func statusData() -> ServerStatus.StatusData {
        ServerStatus.StatusData(
            version: .init(name: "Test Version", protocol: 765),
            players: .init(max: 20, online: 2, sample: nil),
            motd: "Welcome",
            favicon: nil,
            latency: 42
        )
    }
}
