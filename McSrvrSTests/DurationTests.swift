import Foundation
import Testing

@testable import McSrvrS

struct DurationTests {
    @Test func convertsDurationToWholeMilliseconds() {
        let duration = Duration.seconds(2) + .milliseconds(345) + .microseconds(999)

        #expect(duration.milliseconds == 2_345)
    }
}
