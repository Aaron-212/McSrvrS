import Foundation

nonisolated struct ServerAddress: Equatable {
    let host: String
    let port: UInt16?

    init?(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        if trimmedValue.hasPrefix("[") {
            guard
                let closingBracket = trimmedValue.firstIndex(of: "]"),
                closingBracket > trimmedValue.startIndex
            else {
                return nil
            }

            let host = String(trimmedValue[trimmedValue.index(after: trimmedValue.startIndex)..<closingBracket])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let remainderStart = trimmedValue.index(after: closingBracket)
            let remainder = trimmedValue[remainderStart...]

            guard !host.isEmpty else {
                return nil
            }

            if remainder.isEmpty {
                self.host = host
                self.port = nil
                return
            }

            guard remainder.first == ":" else {
                return nil
            }

            guard let port = Self.parsePort(String(remainder.dropFirst())) else {
                return nil
            }

            self.host = host
            self.port = port
            return
        }

        let colonCount = trimmedValue.filter { $0 == ":" }.count
        if colonCount == 0 || colonCount > 1 {
            host = trimmedValue
            port = nil
            return
        }

        let parts = trimmedValue.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return nil
        }

        let host = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, let port = Self.parsePort(String(parts[1])) else {
            return nil
        }

        self.host = host
        self.port = port
    }

    var description: String {
        guard let port else {
            return host
        }

        if host.contains(":") {
            return "[\(host)]:\(port)"
        }

        return "\(host):\(port)"
    }

    var portForDirectConnection: UInt16 {
        port ?? 25565
    }

    var shouldResolveSRV: Bool {
        port == nil && !isIPAddressLiteral
    }

    private static func parsePort(_ value: String) -> UInt16? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedValue.isEmpty,
            trimmedValue.allSatisfy(\.isNumber),
            let port = UInt16(trimmedValue),
            port > 0
        else {
            return nil
        }

        return port
    }

    private var isIPAddressLiteral: Bool {
        host.contains(":") || Self.isIPv4Address(host)
    }

    private static func isIPv4Address(_ value: String) -> Bool {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 4 else {
            return false
        }

        return components.allSatisfy { component in
            guard
                !component.isEmpty,
                component.allSatisfy(\.isNumber),
                let octet = UInt8(component)
            else {
                return false
            }

            return String(octet) == component || component == "0"
        }
    }
}
