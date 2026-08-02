import XCTest

@testable import MagicTapperLib

final class MultitouchDeviceClassifierTests: XCTestCase {
    func testCurrentMagicMouseRecognizedFromMousePreferenceKeys() {
        let descriptor = MultitouchDeviceDescriptor(
            isBuiltIn: false,
            isOpaqueSurface: false,
            preferenceKeys: ["MouseVerticalScroll", "MouseButtonMode"],
            productName: "Renamed Device"
        )

        XCTAssertTrue(MultitouchDeviceClassifier.isMagicMouse(descriptor))
    }

    func testLegacyOpaqueExternalSurfaceRemainsSupported() {
        let descriptor = MultitouchDeviceDescriptor(
            isBuiltIn: false,
            isOpaqueSurface: true,
            preferenceKeys: [],
            productName: nil
        )

        XCTAssertTrue(MultitouchDeviceClassifier.isMagicMouse(descriptor))
    }

    func testProductNameFallbackRecognizesMagicMouse() {
        let descriptor = MultitouchDeviceDescriptor(
            isBuiltIn: false,
            isOpaqueSurface: false,
            preferenceKeys: [],
            productName: "Yuhang’s Magic Mouse"
        )

        XCTAssertTrue(MultitouchDeviceClassifier.isMagicMouse(descriptor))
    }

    func testBuiltInDeviceIsRejected() {
        let descriptor = MultitouchDeviceDescriptor(
            isBuiltIn: true,
            isOpaqueSurface: true,
            preferenceKeys: ["MouseVerticalScroll"],
            productName: "Magic Mouse"
        )

        XCTAssertFalse(MultitouchDeviceClassifier.isMagicMouse(descriptor))
    }

    func testExternalTrackpadIsRejectedBeforeOpaqueFallback() {
        let descriptor = MultitouchDeviceDescriptor(
            isBuiltIn: false,
            isOpaqueSurface: true,
            preferenceKeys: ["TrackpadScroll", "TrackpadRightClick"],
            productName: "Magic Trackpad"
        )

        XCTAssertFalse(MultitouchDeviceClassifier.isMagicMouse(descriptor))
    }

    func testUnknownExternalDeviceIsRejected() {
        let descriptor = MultitouchDeviceDescriptor(
            isBuiltIn: false,
            isOpaqueSurface: false,
            preferenceKeys: [],
            productName: "Unknown Device"
        )

        XCTAssertFalse(MultitouchDeviceClassifier.isMagicMouse(descriptor))
    }
}
