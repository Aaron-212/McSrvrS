import Testing

@testable import McSrvrS

struct ServerAddressTests {
    @Test func parsesHostWithoutPort() throws {
        let address = try #require(ServerAddress("  play.example.net  "))

        #expect(address.host == "play.example.net")
        #expect(address.port == nil)
        #expect(address.description == "play.example.net")
        #expect(address.portForDirectConnection == 25565)
        #expect(address.shouldResolveSRV)
    }

    @Test func parsesHostWithPort() throws {
        let address = try #require(ServerAddress("play.example.net:25566"))

        #expect(address.host == "play.example.net")
        #expect(address.port == 25566)
        #expect(address.description == "play.example.net:25566")
        #expect(address.portForDirectConnection == 25566)
        #expect(!address.shouldResolveSRV)
    }

    @Test func parsesBracketedIPv6WithPort() throws {
        let address = try #require(ServerAddress("[2001:db8::1]:25567"))

        #expect(address.host == "2001:db8::1")
        #expect(address.port == 25567)
        #expect(address.description == "[2001:db8::1]:25567")
        #expect(!address.shouldResolveSRV)
    }

    @Test func treatsIPAddressLiteralsAsDirectConnections() throws {
        let ipv4 = try #require(ServerAddress("192.168.1.10"))
        let ipv6 = try #require(ServerAddress("2001:db8::1"))

        #expect(!ipv4.shouldResolveSRV)
        #expect(!ipv6.shouldResolveSRV)
        #expect(ipv4.portForDirectConnection == 25565)
        #expect(ipv6.portForDirectConnection == 25565)
    }

    @Test func rejectsMalformedAddresses() {
        let invalidAddresses = [
            "",
            "   ",
            ":25565",
            "play.example.net:",
            "play.example.net:0",
            "play.example.net:65536",
            "[2001:db8::1",
            "[]:25565",
            "[2001:db8::1]25565",
        ]

        for value in invalidAddresses {
            #expect(ServerAddress(value) == nil)
        }
    }
}
