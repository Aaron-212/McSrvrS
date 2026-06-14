import Testing

@testable import McSrvrS

struct ServerFormDraftTests {
    @Test func validatesTrimmedNameAndAddress() {
        #expect(ServerFormDraft().isValid == false)
        #expect(ServerFormDraft(server: nil).isValid == false)

        var validDraft = ServerFormDraft()
        validDraft.name = "  Lobby  "
        validDraft.address = " play.example.net "
        #expect(validDraft.isValid)

        var invalidDraft = ServerFormDraft()
        invalidDraft.name = "Lobby"
        invalidDraft.address = "play.example.net:0"
        #expect(!invalidDraft.isValid)
    }

    @Test func appliesCanonicalAddressToExistingServer() {
        let server = Server(name: "Old", address: "old.example.net", orderIndex: 0)
        var draft = ServerFormDraft()
        draft.name = "  New Name  "
        draft.address = " [2001:db8::1]:25566 "

        draft.apply(to: server)

        #expect(server.name == "New Name")
        #expect(server.address == "[2001:db8::1]:25566")
    }

    @Test func createsServerWithTrimmedValues() {
        var draft = ServerFormDraft()
        draft.name = "  Survival  "
        draft.address = " play.example.net:25566 "
        let server = draft.makeServer(orderIndex: 3)

        #expect(server.name == "Survival")
        #expect(server.address == "play.example.net:25566")
        #expect(server.orderIndex == 3)
    }
}
