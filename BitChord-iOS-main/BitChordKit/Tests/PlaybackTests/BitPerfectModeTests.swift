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

/// A Lightning DAC reaches iOS as "Wired headphones", so bit-perfect mode asks for the track's rate
/// on a wired route too; everything else keeps the USB-only rule.
final class WiredRateMatchingTests: XCTestCase {
    func testAWiredRouteIsLeftAloneUnlessBitPerfectAsksForIt() {
        XCTAssertNil(PreferredSampleRatePolicy.preferredSampleRate(outputs: [.wired], trackSampleRate: 96_000))
        XCTAssertEqual(PreferredSampleRatePolicy.preferredSampleRate(outputs: [.wired], trackSampleRate: 96_000, matchWired: true), 96_000)
    }

    func testUsbStillAsksWithoutTheWiredSetting() {
        XCTAssertEqual(PreferredSampleRatePolicy.preferredSampleRate(outputs: [.usb], trackSampleRate: 48_000), 48_000)
    }

    func testOtherRoutesNeverAskEvenInBitPerfectMode() {
        XCTAssertNil(PreferredSampleRatePolicy.preferredSampleRate(outputs: [.bluetooth], trackSampleRate: 96_000, matchWired: true))
        XCTAssertNil(PreferredSampleRatePolicy.preferredSampleRate(outputs: [.phone], trackSampleRate: 96_000, matchWired: true))
        XCTAssertNil(PreferredSampleRatePolicy.preferredSampleRate(outputs: [.wired], trackSampleRate: nil, matchWired: true))
    }
}
