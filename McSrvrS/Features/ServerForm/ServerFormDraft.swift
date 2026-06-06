import Foundation

struct ServerFormDraft: Equatable {
    var name: String
    var address: String

    init(server: Server? = nil) {
        self.name = server?.name ?? ""
        self.address = server?.address ?? ""
    }

    var isValid: Bool {
        !trimmedName.isEmpty && parsedAddress != nil
    }

    func apply(to server: Server) {
        server.name = trimmedName
        server.address = parsedAddress?.description ?? trimmedAddress
        server.lastUpdatedDate = .now
    }

    func makeServer(orderIndex: Int) -> Server {
        Server(
            name: trimmedName,
            address: parsedAddress?.description ?? trimmedAddress,
            orderIndex: orderIndex
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAddress: ServerAddress? {
        ServerAddress(trimmedAddress)
    }
}
