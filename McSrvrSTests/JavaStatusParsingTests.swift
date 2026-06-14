import Testing

@testable import McSrvrS

struct JavaStatusParsingTests {
    @Test func parsesStatusJsonWithObjectDescription() throws {
        let json = """
        {
          "version": { "name": "1.20.4", "protocol": 765 },
          "players": {
            "max": 100,
            "online": 5,
            "sample": [
              {
                "name": "Alex",
                "id": "11111111-2222-3333-4444-555555555555"
              }
            ]
          },
          "description": { "text": "Hello from JSON" },
          "favicon": "data:image/png;base64,abc"
        }
        """

        let response = try JavaServerStatusResponse.parse(json).get()
        let status = response.toStatusData(latency: 17)

        #expect(status.version.name == "1.20.4")
        #expect(status.version.protocol == 765)
        #expect(status.players?.max == 100)
        #expect(status.players?.online == 5)
        #expect(status.players?.sample?.first?.name == "Alex")
        #expect(status.players?.sample?.first?.playerId == "11111111-2222-3333-4444-555555555555")
        #expect(status.motd == "Hello from JSON")
        #expect(status.favicon == "data:image/png;base64,abc")
        #expect(status.latency == 17)
    }

    @Test func parsesStatusJsonWithStringDescription() throws {
        let json = """
        {
          "version": { "name": "1.21", "protocol": 767 },
          "description": "Plain MOTD"
        }
        """

        let response = try JavaServerStatusResponse.parse(json).get()

        #expect(response.motd == "Plain MOTD")
        #expect(response.players == nil)
    }

    @Test func rejectsMalformedStatusJson() {
        let result = JavaServerStatusResponse.parse("{ \"description\": \"missing version\" }")

        if case .success = result {
            Issue.record("Expected malformed status JSON to fail parsing.")
        }
    }
}
