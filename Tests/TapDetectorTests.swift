import XCTest
import Foundation
import CoreGraphics

@testable import MouseToucherLib

class TapDetectorTests: XCTestCase {

    var detector: TapDetector!

    override func setUp() {
        super.setUp()
        detector = TapDetector(
            tapTimeThreshold: 0.3,
            tapMovementThreshold: 5.0,
            rightClickTimeThreshold: 0.1,
            doubleTapTimeWindow: 0.3,
            dragThreshold: 3.0
        )
    }

    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    // MARK: - Basic Tap Detection

    func testValidTap_WithinTimeAndMovementThreshold() {
        let startLocation = CGPoint(x: 100, y: 100)
        let endLocation = CGPoint(x: 102, y: 102) // 2.83 pixels away

        _ = detector.touchBegan(at: startLocation, isRightSide: false)
        let result = detector.touchEnded(at: endLocation, isRightSide: false)

        XCTAssertTrue(result.shouldClick, "Valid tap should trigger a click")
        XCTAssertEqual(result.clickLocation?.x, endLocation.x)
        XCTAssertEqual(result.clickLocation?.y, endLocation.y)
        XCTAssertFalse(result.isRightClick, "Should be a left click")
    }

    func testValidTap_NoMovement() {
        let location = CGPoint(x: 100, y: 100)

        _ = detector.touchBegan(at: location, isRightSide: false)
        let result = detector.touchEnded(at: location, isRightSide: false)

        XCTAssertTrue(result.shouldClick, "Tap with no movement should be valid")
        XCTAssertEqual(result.clickLocation, location)
    }

    func testInvalidTap_ExceedsMovementThreshold() {
        let startLocation = CGPoint(x: 100, y: 100)
        let endLocation = CGPoint(x: 110, y: 110) // 14.14 pixels away

        _ = detector.touchBegan(at: startLocation, isRightSide: false)
        let result = detector.touchEnded(at: endLocation, isRightSide: false)

        XCTAssertFalse(result.shouldClick, "Tap exceeding movement threshold should be invalid")
    }

    func testInvalidTap_ExceedsTimeThreshold() {
        let startLocation = CGPoint(x: 100, y: 100)

        _ = detector.touchBegan(at: startLocation, isRightSide: false)

        // Wait longer than threshold
        Thread.sleep(forTimeInterval: 0.35)

        let result = detector.touchEnded(at: startLocation, isRightSide: false)

        XCTAssertFalse(result.shouldClick, "Tap exceeding time threshold should be invalid")
    }

    // MARK: - Right Click Detection

    func testRightClick_HoldLongEnoughOnRightSide() {
        let location = CGPoint(x: 100, y: 100)

        _ = detector.touchBegan(at: location, isRightSide: true)
        Thread.sleep(forTimeInterval: 0.12) // Longer than right click threshold
        let result = detector.touchEnded(at: location, isRightSide: true)

        XCTAssertTrue(result.shouldClick, "Should trigger click")
        XCTAssertTrue(result.isRightClick, "Should be a right click")
    }

    func testLeftClick_ShortTapOnRightSide() {
        let location = CGPoint(x: 100, y: 100)

        _ = detector.touchBegan(at: location, isRightSide: true)
        // End immediately, before right click threshold
        let result = detector.touchEnded(at: location, isRightSide: true)

        XCTAssertTrue(result.shouldClick, "Should trigger click")
        XCTAssertFalse(result.isRightClick, "Should be a left click (too quick for right click)")
    }

    func testLeftClick_OnLeftSide() {
        let location = CGPoint(x: 100, y: 100)

        _ = detector.touchBegan(at: location, isRightSide: false)
        let result = detector.touchEnded(at: location, isRightSide: false)

        XCTAssertTrue(result.shouldClick, "Should trigger click")
        XCTAssertFalse(result.isRightClick, "Should be a left click")
    }

    // MARK: - Double Tap Drag Detection

    func testDoubleTapDrag_EntersDragMode() {
        let location1 = CGPoint(x: 100, y: 100)
        let location2 = CGPoint(x: 100, y: 100)

        // First tap
        _ = detector.touchBegan(at: location1, isRightSide: false)
        let result1 = detector.touchEnded(at: location1, isRightSide: false)
        XCTAssertTrue(result1.shouldClick)

        // Second tap within double-tap window
        Thread.sleep(forTimeInterval: 0.1) // Within 0.3s window
        let result2 = detector.touchBegan(at: location2, isRightSide: false)

        XCTAssertTrue(result2.isDragging, "Should enter dragging mode")
        XCTAssertTrue(detector.isDragging, "Detector should be in dragging state")
    }

    func testDoubleTapDrag_MovementWhileDragging() {
        let location1 = CGPoint(x: 100, y: 100)
        let location2 = CGPoint(x: 100, y: 100)
        let moveLocation = CGPoint(x: 110, y: 110)

        // First tap
        _ = detector.touchBegan(at: location1, isRightSide: false)
        _ = detector.touchEnded(at: location1, isRightSide: false)

        // Second tap to enter drag mode
        Thread.sleep(forTimeInterval: 0.1)
        _ = detector.touchBegan(at: location2, isRightSide: false)

        // Move while dragging
        let moveResult = detector.touchMoved(to: moveLocation)
        XCTAssertTrue(moveResult.isDragging, "Should still be dragging")
        XCTAssertNotNil(moveResult.dragLocation, "Should return drag location")
    }

    func testDoubleTapDrag_EndsWhenReleased() {
        let location1 = CGPoint(x: 100, y: 100)

        // First tap
        _ = detector.touchBegan(at: location1, isRightSide: false)
        _ = detector.touchEnded(at: location1, isRightSide: false)

        // Second tap to enter drag mode
        Thread.sleep(forTimeInterval: 0.1)
        _ = detector.touchBegan(at: location1, isRightSide: false)
        XCTAssertTrue(detector.isDragging)

        // End drag
        let endResult = detector.touchEnded(at: location1, isRightSide: false)
        XCTAssertFalse(endResult.isDragging, "Should not be dragging after release")
        XCTAssertFalse(detector.isDragging, "Detector should not be in dragging state")
    }

    func testDoubleTapDrag_TimedOut() {
        let location1 = CGPoint(x: 100, y: 100)
        let location2 = CGPoint(x: 100, y: 100)

        // First tap
        _ = detector.touchBegan(at: location1, isRightSide: false)
        _ = detector.touchEnded(at: location1, isRightSide: false)

        // Wait too long (outside double-tap window)
        Thread.sleep(forTimeInterval: 0.4)

        // Second tap - should NOT enter drag mode
        let result2 = detector.touchBegan(at: location2, isRightSide: false)
        XCTAssertFalse(result2.isDragging, "Should not enter drag mode after timeout")
    }

    // MARK: - Drag Threshold (Anti-jitter)

    func testDragThreshold_SmallMovementIgnored() {
        let location1 = CGPoint(x: 100, y: 100)
        let location2 = CGPoint(x: 100, y: 100)
        let smallMove = CGPoint(x: 101, y: 101) // 1.41 pixels, under 3.0 threshold

        // Enter drag mode
        _ = detector.touchBegan(at: location1, isRightSide: false)
        _ = detector.touchEnded(at: location1, isRightSide: false)
        Thread.sleep(forTimeInterval: 0.1)
        _ = detector.touchBegan(at: location2, isRightSide: false)

        // Small movement should not generate drag event
        let moveResult = detector.touchMoved(to: smallMove)
        XCTAssertTrue(moveResult.isDragging, "Should still be dragging")
        XCTAssertNil(moveResult.dragLocation, "Should not generate drag location for small movement")
    }

    func testDragThreshold_LargeMovementAccepted() {
        let location1 = CGPoint(x: 100, y: 100)
        let location2 = CGPoint(x: 100, y: 100)
        let largeMove = CGPoint(x: 105, y: 105) // 7.07 pixels, over 3.0 threshold

        // Enter drag mode
        _ = detector.touchBegan(at: location1, isRightSide: false)
        _ = detector.touchEnded(at: location1, isRightSide: false)
        Thread.sleep(forTimeInterval: 0.1)
        _ = detector.touchBegan(at: location2, isRightSide: false)

        // Large movement should generate drag event
        let moveResult = detector.touchMoved(to: largeMove)
        XCTAssertTrue(moveResult.isDragging, "Should still be dragging")
        XCTAssertNotNil(moveResult.dragLocation, "Should generate drag location for large movement")
    }

    // MARK: - State Management

    func testReset_ClearsAllState() {
        let location = CGPoint(x: 100, y: 100)

        _ = detector.touchBegan(at: location, isRightSide: false)
        XCTAssertTrue(detector.isTracking)

        detector.reset()
        XCTAssertFalse(detector.isTracking)
        XCTAssertFalse(detector.isDragging)

        let result = detector.touchEnded(at: location, isRightSide: false)
        XCTAssertFalse(result.shouldClick, "Should not detect tap after reset")
    }

    func testIsTracking_InitiallyFalse() {
        XCTAssertFalse(detector.isTracking, "Detector should not be tracking initially")
    }

    func testIsTracking_TrueAfterTouchBegan() {
        _ = detector.touchBegan(at: CGPoint(x: 100, y: 100), isRightSide: false)
        XCTAssertTrue(detector.isTracking, "Detector should be tracking after touch began")
    }

    func testState_TransitionsCorrectly() {
        XCTAssertEqual(detector.state, .idle, "Should start in idle state")

        _ = detector.touchBegan(at: CGPoint(x: 100, y: 100), isRightSide: false)
        XCTAssertEqual(detector.state, .touching, "Should be in touching state")

        _ = detector.touchEnded(at: CGPoint(x: 100, y: 100), isRightSide: false)
        XCTAssertEqual(detector.state, .idle, "Should return to idle state")
    }

    // MARK: - Edge Cases

    func testTouchEnded_WithoutTouchBegan() {
        let location = CGPoint(x: 100, y: 100)
        let result = detector.touchEnded(at: location, isRightSide: false)

        XCTAssertFalse(result.shouldClick, "Should not detect tap without touchBegan")
    }

    func testTouchMoved_WithoutTouchBegan() {
        let location = CGPoint(x: 100, y: 100)
        let result = detector.touchMoved(to: location)

        XCTAssertFalse(result.isDragging, "Should handle touchMoved without touchBegan")
    }

    // MARK: - Performance

    func testPerformance_RapidTaps() {
        measure {
            for i in 0..<1000 {
                let location = CGPoint(x: CGFloat(i % 100), y: CGFloat(i / 100))
                _ = detector.touchBegan(at: location, isRightSide: false)
                _ = detector.touchEnded(at: location, isRightSide: false)
            }
        }
    }
}
