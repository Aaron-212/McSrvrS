import Foundation
import Testing

@testable import McSrvrS

struct MinecraftProtocolCodecTests {
    @Test func packsKnownVarIntValues() {
        let examples: [(Int, [UInt8])] = [
            (0, [0x00]),
            (1, [0x01]),
            (127, [0x7F]),
            (128, [0x80, 0x01]),
            (255, [0xFF, 0x01]),
            (2_147_483_647, [0xFF, 0xFF, 0xFF, 0xFF, 0x07]),
        ]

        for (value, bytes) in examples {
            #expect(MinecraftProtocolCodec.packVarInt(value) == Data(bytes))
            #expect(MinecraftProtocolCodec.varIntSize(value) == bytes.count)
        }
    }
}
