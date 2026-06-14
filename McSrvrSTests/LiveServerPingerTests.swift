import Testing

@testable import McSrvrS

struct LiveServerPingerTests {
    @Test func pingsHypixelWhenRealServerTestsAreEnabled() async throws {
        let result = await JavaServerPinger.shared.ping(address: "play.hypixel.net")
        let status = try result.get()

        #expect(status.version.name.isEmpty == false)
        #expect((status.players?.max ?? 0) > 0)
        #expect(status.latency != nil)
    }
}
