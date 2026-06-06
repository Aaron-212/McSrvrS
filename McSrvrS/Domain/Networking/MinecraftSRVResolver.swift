import Dispatch
import Foundation
import dnssd

nonisolated struct ResolvedServerAddress: Sendable {
    let host: String
    let port: UInt16
}

nonisolated enum MinecraftSRVResolver {
    private static let timeout: TimeInterval = 2

    static func resolve(_ address: ServerAddress) async -> ResolvedServerAddress {
        if let port = address.port {
            return ResolvedServerAddress(host: address.host, port: port)
        }

        guard let resolvedAddress = await resolveSRV(address)
        else {
            return ResolvedServerAddress(
                host: address.host,
                port: address.portForDirectConnection
            )
        }

        return resolvedAddress
    }

    static func resolveSRV(_ address: ServerAddress) async -> ResolvedServerAddress? {
        guard address.shouldResolveSRV,
            let record = await querySRVRecord(for: address.host)
        else {
            return nil
        }

        return ResolvedServerAddress(host: record.target, port: record.port)
    }

    private static func querySRVRecord(for host: String) async -> SRVRecord? {
        await withCheckedContinuation { continuation in
            let context = SRVLookupContext(continuation: continuation)
            let retainedContext = Unmanaged.passRetained(context)
            context.retainedContext = retainedContext

            var serviceRef: DNSServiceRef?
            let error = DNSServiceQueryRecord(
                &serviceRef,
                DNSServiceFlags(0),
                0,
                "_minecraft._tcp.\(host)",
                UInt16(kDNSServiceType_SRV),
                UInt16(kDNSServiceClass_IN),
                srvQueryCallback,
                retainedContext.toOpaque()
            )

            guard error == kDNSServiceErr_NoError, let serviceRef else {
                retainedContext.release()
                continuation.resume(returning: nil)
                return
            }

            context.serviceRef = serviceRef

            let queue = DispatchQueue(label: "personal.aaron212.mcsrvrs.srv-resolver")
            let dispatchError = DNSServiceSetDispatchQueue(serviceRef, queue)
            guard dispatchError == kDNSServiceErr_NoError else {
                context.finish()
                return
            }

            context.startTimeout(on: queue, after: timeout)
        }
    }

    private static let srvQueryCallback: DNSServiceQueryRecordReply = {
        _,
        flags,
        _,
        errorCode,
        _,
        _,
        _,
        dataLength,
        data,
        _,
        contextPointer in
        guard let contextPointer else {
            return
        }

        let context = Unmanaged<SRVLookupContext>.fromOpaque(contextPointer).takeUnretainedValue()
        context.handle(
            flags: flags,
            errorCode: errorCode,
            dataLength: dataLength,
            data: data
        )
    }
}

private nonisolated struct SRVRecord {
    let priority: UInt16
    let weight: UInt16
    let port: UInt16
    let target: String
}

private nonisolated final class SRVLookupContext {
    var retainedContext: Unmanaged<SRVLookupContext>?
    var serviceRef: DNSServiceRef?

    private var continuation: CheckedContinuation<SRVRecord?, Never>?
    private var records: [SRVRecord] = []
    private var timeoutWorkItem: DispatchWorkItem?
    private var isFinished = false

    init(continuation: CheckedContinuation<SRVRecord?, Never>) {
        self.continuation = continuation
    }

    func startTimeout(on queue: DispatchQueue, after timeout: TimeInterval) {
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.finish()
        }
        self.timeoutWorkItem = timeoutWorkItem
        queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
    }

    func handle(
        flags: DNSServiceFlags,
        errorCode: DNSServiceErrorType,
        dataLength: UInt16,
        data: UnsafeRawPointer?
    ) {
        guard !isFinished else {
            return
        }

        if errorCode != kDNSServiceErr_NoError {
            finish()
            return
        }

        if let data,
            let record = SRVRecord(data: Data(bytes: data, count: Int(dataLength)))
        {
            records.append(record)
        }

        if flags & DNSServiceFlags(kDNSServiceFlagsMoreComing) == 0 {
            finish()
        }
    }

    func finish() {
        guard !isFinished else {
            return
        }

        isFinished = true
        timeoutWorkItem?.cancel()

        let record = Self.selectRecord(from: records)
        let continuation = continuation
        let serviceRef = serviceRef
        let retainedContext = retainedContext

        self.continuation = nil
        self.serviceRef = nil
        self.retainedContext = nil
        records.removeAll()

        if let serviceRef {
            DNSServiceRefDeallocate(serviceRef)
        }

        continuation?.resume(returning: record)
        retainedContext?.release()
    }

    private static func selectRecord(from records: [SRVRecord]) -> SRVRecord? {
        let minimumPriority = records.map(\.priority).min()
        let candidates = records.filter { $0.priority == minimumPriority }
        let totalWeight = candidates.reduce(UInt32(0)) { $0 + UInt32($1.weight) }

        guard totalWeight > 0 else {
            return candidates.first
        }

        var selectedWeight = UInt32.random(in: 1...totalWeight)
        for candidate in candidates {
            let weight = UInt32(candidate.weight)
            if selectedWeight <= weight {
                return candidate
            }
            selectedWeight -= weight
        }

        return candidates.last
    }
}

private nonisolated extension SRVRecord {
    init?(data: Data) {
        guard data.count >= 7 else {
            return nil
        }

        self.priority = Self.readUInt16(from: data, at: 0)
        self.weight = Self.readUInt16(from: data, at: 2)
        self.port = Self.readUInt16(from: data, at: 4)

        guard let target = Self.readDomainName(from: data, at: 6), !target.isEmpty else {
            return nil
        }

        self.target = target
    }

    private static func readUInt16(from data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func readDomainName(from data: Data, at offset: Int) -> String? {
        var labels: [String] = []
        var index = offset

        while index < data.count {
            let length = Int(data[index])
            index += 1

            if length == 0 {
                return labels.joined(separator: ".")
            }

            guard length & 0xC0 == 0, index + length <= data.count else {
                return nil
            }

            let labelData = data[index..<(index + length)]
            guard let label = String(data: labelData, encoding: .utf8) else {
                return nil
            }

            labels.append(label)
            index += length
        }

        return nil
    }
}
