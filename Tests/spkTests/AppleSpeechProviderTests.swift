import XCTest
@testable import Spk

final class AppleSpeechProviderTests: XCTestCase {
    func testIsStoppingIntentionallyDefaultsToFalse() {
        let provider = AppleSpeechProvider()
        XCTAssertFalse(provider.isStoppingIntentionally)
    }

    func testStopSetsStoppingFlag() {
        let provider = AppleSpeechProvider()
        provider.stop()
        XCTAssertTrue(provider.isStoppingIntentionally)
    }

    func testCleanupResetsStoppingFlag() {
        let provider = AppleSpeechProvider()
        provider.isStoppingIntentionally = true
        provider.cleanup()
        XCTAssertFalse(provider.isStoppingIntentionally)
    }

    func testCleanupClearsState() {
        let provider = AppleSpeechProvider()
        // After cleanup, the provider should be in a clean state
        provider.cleanup()
        XCTAssertFalse(provider.isStoppingIntentionally)
    }
}
