import XCTest

@testable import MagicTapperLib

class TapConfigurationTests: XCTestCase {

    func testDefaultConfigurationMatchesInitializerDefaults() {
        XCTAssertEqual(TapConfiguration.default, TapConfiguration())
    }

    func testDefaultConfigurationUsesExpectedRightClickArea() {
        XCTAssertEqual(TapConfiguration.default.rightClickAreaThreshold, 0.6, accuracy: 0.001)
    }
}
