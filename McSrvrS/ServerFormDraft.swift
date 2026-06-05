import Foundation

struct ServerFormDraft: Equatable {
    var name: String
    var host: String
    var port: UInt16?

    init(server: Server? = nil) {
        self.name = server?.name ?? ""
        self.host = server?.host ?? ""
        self.port = server?.port ?? 25565
    }

    var isValid: Bool {
        !trimmedName.isEmpty && !trimmedHost.isEmpty
    }

    func apply(to server: Server) {
        server.name = trimmedName
        server.host = trimmedHost
        server.port = portNumber
        server.lastUpdatedDate = .now
    }

    func makeServer(orderIndex: Int) -> Server {
        Server(
            name: trimmedName,
            host: trimmedHost,
            port: portNumber,
            orderIndex: orderIndex
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var portNumber: UInt16 {
        port ?? 25565
    }
}
