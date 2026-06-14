import Foundation
import Testing

@testable import McSrvrS

struct MotdFormattingTests {
    @Test func trimsWhitespaceAcrossLines() {
        let value = "  Line one  \n\tLine two\t\nLine three  "

        #expect(value.trimmingWhitespace() == "Line one Line two Line three")
    }

    @Test func removesMinecraftFormatCodes() {
        #expect("§aGreen §lBold §rPlain".trimmingFormatCodes() == "Green Bold Plain")
    }

    @Test func parseMotdPreservesTextWhileSkippingColorWhenRequested() throws {
        let status = ServerStatus.StatusData(
            version: .init(name: "Test Version", protocol: 765),
            players: nil,
            motd: "§aHello\n§lWorld",
            favicon: nil,
            latency: nil
        )

        let attributed = try #require(status.parseMotd(skipColor: true, trimWhitespace: true))

        #expect(String(attributed.characters) == "Hello World")
    }
}
