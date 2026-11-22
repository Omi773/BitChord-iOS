import XCTest
@testable import Playback

/// The refused-rate memory behind the USB sample-rate negotiation.
final class RateSupportCacheTests: XCTestCase {
    func testARateIsNotRefusedUntilRecorded() {
        let cache = RateSupportCache()
        XCTAssertFalse(cache.isRefused(route: "USB", rate: 176_400))
    }

    func testARefusedRateIsRememberedPerRouteAndRate() {
        var cache = RateSupportCache()
        cache.recordRefused(route: "USB", rate: 176_400)
        XCTAssertTrue(cache.isRefused(route: "USB", rate: 176_400))
        XCTAssertFalse(cache.isRefused(route: "USB", rate: 88_200), "another rate on the same DAC is still worth asking for")
        XCTAssertFalse(cache.isRefused(route: "Headphones", rate: 176_400), "another route is a different device")
    }

    func testAnAcceptedRateIsForgottenAsRefused() {
        var cache = RateSupportCache()
        cache.recordRefused(route: "USB", rate: 96_000)
        cache.recordAccepted(route: "USB", rate: 96_000)
        XCTAssertFalse(cache.isRefused(route: "USB", rate: 96_000))
    }

    func testRatesAreKeyedToTheNearestHertz() {
        var cache = RateSupportCache()
        cache.recordRefused(route: "USB", rate: 44_100.2)
        XCTAssertTrue(cache.isRefused(route: "USB", rate: 44_100))
    }
}
