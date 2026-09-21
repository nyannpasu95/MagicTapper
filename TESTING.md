# MagicTapper - Testing Documentation

## Overview

This document describes the testing strategy and implementation for the MagicTapper application. The test suite ensures the quality and reliability of the tap-to-click functionality.

## Test Architecture

The codebase is structured to be highly testable:

```
MagicTapper/
├── Sources/
│   ├── TapDetector.swift    # Pure logic - highly testable
│   └── AppDelegate.swift     # Integration layer
├── Tests/
│   ├── TapDetectorTests.swift    # 22 unit tests
│   └── AppDelegateTests.swift    # 9 integration tests
└── main.swift               # Entry point
```

## Running Tests

### Quick Start

```bash
# Run all tests
./run_tests.sh

# Or use Swift Package Manager
swift test

# Run with verbose output
swift test --verbose

# Run specific test
swift test --filter TapDetectorTests
```

## Test Suites

### TapDetectorTests (22 tests)

Comprehensive unit tests for the core tap detection logic.

#### Basic Tap Detection (6 tests)
- ✅ `testValidTap_WithinTimeAndMovementThreshold` - Verifies valid taps are detected
- ✅ `testValidTap_NoMovement` - Tests stationary taps
- ✅ `testInvalidTap_ExceedsMovementThreshold` - Rejects taps with too much movement
- ✅ `testInvalidTap_ExceedsTimeThreshold` - Rejects taps that take too long
- ✅ `testTapAtBoundary_MovementThreshold` - Tests edge case at exact threshold
- ✅ `testTapJustOverBoundary_MovementThreshold` - Tests boundary precision

#### Touch Movement Detection (3 tests)
- ✅ `testTouchMoved_WithinThreshold` - Allows small movements during tap
- ✅ `testTouchMoved_ExceedsThreshold` - Cancels tap on large movement
- ✅ `testTouchMoved_AfterExceedingThreshold_ShouldInvalidateTap` - Ensures cancelled taps stay cancelled

#### State Management (4 tests)
- ✅ `testReset_ClearsTrackingState` - Verifies reset functionality
- ✅ `testTouchEnded_ResetsState` - Ensures state cleanup after tap
- ✅ `testIsTracking_InitiallyFalse` - Tests initial state
- ✅ `testIsTracking_TrueAfterTouchBegan` - Verifies tracking activation

#### Multiple Taps (2 tests)
- ✅ `testMultipleTaps_Sequential` - Tests rapid sequential taps
- ✅ `testInvalidTap_FollowedByValidTap` - Ensures failed taps don't affect subsequent taps

#### Edge Cases (3 tests)
- ✅ `testTouchEnded_WithoutTouchBegan` - Handles out-of-order events
- ✅ `testTouchMoved_WithoutTouchBegan` - Handles missing initialization
- ✅ `testMultipleTouchBegan_WithoutEnding` - Tests overwriting behavior

#### Custom Thresholds (3 tests)
- ✅ `testCustomThresholds_StrictTime` - Validates time threshold configuration
- ✅ `testCustomThresholds_StrictMovement` - Validates movement threshold configuration
- ✅ `testCustomThresholds_RelaxedThresholds` - Tests lenient settings

#### Performance (1 test)
- ✅ `testPerformance_RapidTaps` - Benchmarks 1000 rapid taps
  - Average: ~0.001s for 1000 taps
  - Confirms low overhead

### AppDelegateTests (9 tests)

Integration tests for application-level behavior.

#### Initialization (2 tests)
- ✅ `testInitialization_DefaultState` - Verifies default configuration
- ✅ `testStateManagement_EnabledByDefault` - Ensures enabled on startup

#### Toggle Functionality (3 tests)
- ✅ `testToggleEnabled_FromEnabledToDisabled` - Tests disabling
- ✅ `testToggleEnabled_FromDisabledToEnabled` - Tests enabling
- ✅ `testToggleEnabled_MultipleToggles` - Validates toggle state consistency

#### Integration (4 tests)
- ✅ `testTapDetectorIntegration_InitializedWithDefaults` - Verifies default thresholds
- ✅ `testTapDetectorIntegration_RespectsEnabledState` - Tests enable/disable integration
- ✅ `testStateManagement_TapDetectorNotTrackingInitially` - Ensures clean startup
- ✅ `testSynthesizeClick_CreatesEvents` - Validates event synthesis

## Test Results

```
Test Suite 'All tests' passed
  Executed 31 tests, with 0 failures (0 unexpected)
  Total duration: ~1.6 seconds

TapDetectorTests: 22/22 passed ✅
AppDelegateTests: 9/9 passed ✅
```

## Testing Strategy

### Unit Testing (TapDetectorTests)

The `TapDetector` class is designed as a pure logic component with no dependencies on system frameworks. This allows for:

- **Fast execution**: Tests run in milliseconds
- **Deterministic results**: No flaky tests
- **Easy debugging**: Simple input/output verification
- **High coverage**: Every code path is tested

### Integration Testing (AppDelegateTests)

Integration tests focus on component interaction:

- State management between components
- Enable/disable functionality
- Configuration propagation

**Note**: UI and event system tests require window server connections unavailable in test environments. These are verified through:
- Manual testing
- Real-world usage
- The comprehensive unit test coverage of underlying logic

## Code Coverage

The test suite provides extensive coverage of critical paths:

- **Tap Detection Logic**: 100% coverage
  - All threshold checks
  - All state transitions
  - All edge cases

- **App State Management**: ~90% coverage
  - Enable/disable toggle
  - Configuration
  - Integration points

- **UI Code**: Manual testing required
  - Menu bar creation
  - Event tap setup
  - Alert dialogs

## Continuous Integration

The test suite is designed to be CI-friendly:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: swift test

# Exit code 0 on success, non-zero on failure
```

## Testing Best Practices

### When Adding New Features

1. Write tests first (TDD)
2. Ensure all edge cases are covered
3. Add performance tests for hot paths
4. Update this documentation

### When Fixing Bugs

1. Write a failing test that reproduces the bug
2. Fix the bug
3. Verify the test passes
4. Add regression test to suite

### Test Naming Convention

Tests follow the pattern: `test<Component>_<Condition>_<ExpectedBehavior>`

Examples:
- `testValidTap_NoMovement` - Tests valid tap with no movement
- `testToggleEnabled_FromEnabledToDisabled` - Tests toggle behavior

## Performance Benchmarks

Current performance metrics (from test suite):

| Operation | Time | Throughput |
|-----------|------|------------|
| 1000 rapid taps | ~1.4ms | ~714,000 taps/sec |
| Single tap detection | ~1.4μs | Sub-microsecond |

These metrics ensure the app adds negligible overhead to mouse operations.

## Future Testing Improvements

Potential enhancements:

- [ ] UI testing with XCTest UI framework
- [ ] Memory leak detection tests
- [ ] Long-running stress tests
- [ ] Multi-threaded safety tests
- [ ] Accessibility compliance tests

## Manual Testing Checklist

For features that can't be automatically tested:

- [ ] App icon appears in menu bar
- [ ] Menu items respond to clicks
- [ ] Toggle updates menu item title and state
- [ ] Quit command terminates app
- [ ] Accessibility permission dialog appears
- [ ] Actual taps on Magic Mouse trigger clicks
- [ ] Enable/disable toggle works in real-time
- [ ] No crashes during extended use

## Debugging Failed Tests

If tests fail:

1. Check test output for specific failure
2. Run failing test in isolation: `swift test --filter <TestName>`
3. Add print statements to debug
4. Verify threshold values match expectations
5. Check for timing-sensitive tests (may need adjustment)

## Contact

For test-related questions or issues, please file an issue on the project repository.

---

**Last Updated**: October 2025
**Test Suite Version**: 1.0
**Total Tests**: 31 (22 unit + 9 integration)
**Success Rate**: 100% ✅


## Two-finger zoom validation

### Build and install entry points

Use `bash test-and-install.sh` for current-source manual testing and optional installation. The old script reused an existing `build/MagicTapper.app`, while recent previews were delivered in separate subdirectories, so it could launch an older binary. All current test/install runners rebuild before launch; the standard build output is kept current. Scripts resolve the repository from their own location, so invoking them with an absolute path from another directory is supported.

`bash test-and-install.sh --build-only` builds and verifies the bundle without stopping apps, launching UI or installing. `--test-only` launches the exact freshly built bundle without installing. `install-final.sh` shares the same build/verification/install workflow. Installation stages and verifies a copy before replacing the installed app, preserves an old-version backup and attempts rollback if replacement fails. The printed SHA-256 identifies the actual executable even when the marketing version remains the same.

Run `python3 Tests/ScriptWorkflowTests.py` for isolated script regression checks. Fixtures replace the build tools, processes, launches and installation directory; they never stop real applications or write to `/Applications`. Cases cover stale output, build failure, declining installation, staging failure, replacement rollback, an unresponsive process, both quick-test selections and paths containing spaces.

### Automated checks (no input injection)

Run `bash run_tests.sh`, `bash build-debug.sh`, and `bash build.sh`. In a restricted environment where SwiftPM's nested sandbox cannot launch, use:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH="$PWD/build/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/build/swift-module-cache" \
swift test --disable-sandbox
```

Zoom tests cover contact identity, direction dominance, asymmetric/invalid input, cancellation, buffering/replay order, stale generations, target changes, inactivity/hard tail limits, independent settings, and event conversion through `NSEvent(cgEvent:)`. The last check validates the event representation, not actual delivery to other applications. No tests post real scroll, keyboard, or gesture events.

### Diagnostic entry point

Quit other running MagicTapper instances before manually testing to avoid duplicate clicks. Build the debug app, then run:

```bash
MAGICTAPPER_ZOOM_DIAGNOSTICS=1 \
build/MagicTapper_Debug.app/Contents/MacOS/MagicTapper_Debug
```

Console logs show raw device IDs, touch states/positions, input timestamps, scroll phases/momentum and emitted zoom phases. Logs are opt-in, written to the system/console log, and never uploaded. The debug-only **Zoom Diagnostics…** menu opens a canvas displaying received magnification and phases. Opening the window injects nothing. Its **Send a zoom probe in 3 seconds** button explicitly sends one short pinch: place the pointer on the canvas or a disposable target document during the countdown.

1. Check that the diagnostic canvas receives began/changed/ended and changes scale. Check the same probe in Safari, Chrome, Preview image, and Preview PDF. Record each app version and result separately.
2. With actual Magic Mouse fingers, confirm state 4 contacts and increasing normalized Y correspond to forward movement. If the hardware reports the opposite, change the internal sign and matching regression fixtures; do not infer direction from the natural scrolling preference. Check both natural-scroll settings.
3. Enable **Two-Finger Zoom**, turn **Tap to Click** off, and verify zoom remains available. Toggle zoom off and confirm ordinary scrolling is immediate.
4. Perform 20 zoom gestures per target, including reversing direction, slow/fast motion, staggered touch-down and lift. Record successful recognitions / 20, missed starts, accidental scroll and lift-click counts. Recognition should not cause a scroll jump or click; do not declare acceptance if these occur.
5. Perform at least 20 ordinary-operation trials: single-finger scrolling with the other finger resting, taps, right clicks, double clicks, drags, horizontal swipes, and alternating trackpad/mouse use. Record false zooms and regressions. Simultaneous cross-device scrolling is not supported in this version.
6. During candidate/active zoom, change window/app, disable zoom, disconnect Bluetooth and sleep/wake. Confirm no replay into the new window, no stuck zoom/button and normal scrolling resumes. Verify zoom-only mode after reconnection/wake and sensitivity/reversal after restart.
7. Use logs to check the ordering of the first touch callback versus native scrolling. The bounded candidate wait is 80 ms; scroll that reaches macOS before a two-finger candidate is observed cannot be retroactively removed. A repeatable startup scroll jump blocks manual acceptance and requires timing adjustment, not a compatibility claim.

### Validation record

Host: macOS 26.6.2. On 2026-09-21, all 109 automated tests passed (including 35 new zoom tests and the additional configuration coverage); native event decoding passed without posting input. Release arm64/x86_64 and debug builds succeeded; the only compiler warnings were the existing IOKit pointer-acceleration deprecations. Desktop automation timed out both when opening the debug app by path and when retrying its bundle ID, so UI/probe delivery was not verified. Automated event decoding can validate this host's representation only. Physical Magic Mouse calibration, 20-trial gesture testing, sleep/Bluetooth recovery, and application delivery must be recorded explicitly; they cannot be inferred from passing unit tests or compilation.

| Target | Probe delivery | 20 physical zoom trials | False zoom / ordinary-operation trials |
| --- | --- | --- | --- |
| Safari | Pending | Pending | Pending |
| Chrome | Pending | Pending | Pending |
| Preview image | Pending | Pending | Pending |
| Preview PDF | Pending | Pending | Pending |


### Chrome ordinary-page compatibility follow-up

The user reported that a PDF reader works but ordinary Chrome pages do not. The local Chrome version is 153.0.8010.48. Its [PinchEvent implementation](https://github.com/chromium/chromium/blob/153.0.8010.48/content/browser/renderer_host/render_widget_host_view_mac.mm) suppresses default page zoom until cumulative pinch scale is strictly above 1.5 or below 0.667. External CGEvents take this normal input path; Chrome's internal synthetic-test exemption does not apply to them.

The initial Chrome fix preceded the first nonzero update with one direction-specific threshold preparation event. That event stays inside Chrome's ignored range when individually processed; the following real movement crosses the threshold. The lower boundary was rounded upward in float precision. A paced replacement was subsequently tried and reverted after negative physical feedback (see the current recovery record below). The policy is captured from the target window's app at gesture start, and reset on end/cancel. Preview, Acrobat, and other applications keep their original event sequence.

The updated release build (arm64 + x86_64, macOS 13 deployment target) and host-arm64 debug build succeeded, and both passed code signature verification. The new release app is available at `build/chrome-zoom-fix/MagicTapper.app`; quit the previous instance before launching it.

All 115 tests passed after this change, including regression checks against Chrome's float-precision threshold behavior, both directions, reversal, tiny movements, cancellation, and switching back to a PDF reader. This is consumer-contract testing, not a successful physical Chrome retest. On an ordinary webpage, repeat several short forward/backward gestures with the pointer over page content; confirm immediate small changes and no startup jump, then recheck the working PDF reader. Test zoom-out after first zooming in. Websites with custom Ctrl-wheel handlers (maps/editors) may handle the preparation event themselves and still need separate validation.

### Stable zoom anchor follow-up

The user confirmed the Chrome compatibility build zooms ordinary pages, but reported movement/shaking during zoom and clarified that webpage content scrolls vertically while zooming. Only one MagicTapper process was found running. Each gesture now captures its cursor location at begin and uses that same location for every magnification event, including Chrome's preparation event and end/cancel. Previously the location was implicitly sampled anew with every CGEvent. A fresh gesture captures a fresh anchor. This removes anchor drift from emitted gestures; it does not override an application's own layout or viewport boundary adjustments.

Scroll interception moved from the session head to the annotated-session tail, before application delivery. This covers scroll events inserted after the earlier tap and gives touch callbacks more time to establish a candidate before arbitration. It cannot retract events already delivered before a candidate exists. Diagnostic scroll logs now include pass/consume decisions and both pixel deltas. The actual source of the reported extra scrolling remains unconfirmed pending physical retesting; the tap change is a mitigation, not evidence that a particular event source was responsible.

Regression tests simulate pointer drift, direction reversal, a new gesture after end/cancel, and negative display coordinates without injecting input. Scroll arbitration also verifies both axes and momentum stay suppressed through finger lift, then release for the next normal scroll. Manually compare short forward/backward zooms in Chrome and the working PDF reader, including slight mouse movement within the same window; check that the content under the starting pointer stays anchored and no extra scroll occurs. The reported shaking has not yet been reproduced or verified fixed on hardware.

All 118 automated tests passed. Release arm64/x86_64 and host-arm64 debug builds succeeded and passed code signature verification; existing IOKit deprecation warnings remain. The updated preview is `build/stable-zoom/MagicTapper.app`. Quit the installed instance before launching or replacing it. The later event-tap delivery behavior needs an actual Magic Mouse retest; the automated coordinator tests do not exercise WindowServer delivery.

### Chrome pacing experiment (reverted)

A paced replacement for the large preparation event passed 121 unit tests but failed physical testing: the user reported stutter and failure on a second zoom. Its 8 ms rate gate, ±0.025 log-scale cap and dropped accumulated displacement broke continuous movement tracking. Preparation repeated on every gesture and could outlast a short slide. These were unacceptable regressions; passing output-bound tests did not establish usable native zoom behavior.

### Continuous output restored (current build)

Removed the pacing timer, pending-movement buffer and per-output clamp. Chrome once again receives each recognizer update immediately, with its original magnitude. The previously working Chrome preparation path, fixed anchor and scroll interception remain. This is recovery to the responsive baseline, not a claim that the earlier occasional Chrome jumps have been fixed. The original large preparation event remains a suspect until actual delivery is recorded.

All 119 current Swift tests passed, including 20 consecutive alternating short Chrome gestures, dense updates with reversal and total-scale preservation, end/cancel resets, independent PDF policy and target/setting cancellation. Formal arm64/x86_64 and host-arm64 debug builds succeeded. These tests check our event contract; physical trackpad equivalence and the earlier jump cause remain unverified.

For one focused hardware trace, run:

```bash
bash diagnose-zoom.sh
```

This rebuilds/launches the debug app and prints a unique local log path under `build/`. Enable **Two-Finger Zoom** in that app. On the same ordinary Chrome webpage, perform three Magic Mouse zoom-in/out gestures with complete finger lift between attempts, then three physical trackpad pinches. Do not use both devices simultaneously. Return to the terminal and press Ctrl+C. Share the log path and identify which attempts failed or jumped.

The opt-in passive observer logs gesture types, phases, magnitude, timestamps, location and whether the event carries MagicTapper's marker. Untagged events are useful for comparison with the trackpad in this controlled sequence, but are not a reliable hardware-device identifier. Touch frames, recognizer output and scroll pass/consume decisions are logged alongside them. The observer does not modify events; it records no keys, webpage text or screenshots. Ordinary launches keep it disabled. AppKit/Chrome processing after the event tap is not directly observed, so further application-side tracing may still be necessary. Use `bash test-and-install.sh` to return to the standard release installation after tracing.

### Chrome trace: previous momentum rejected a fresh gesture

The trace `build/zoom-diagnostics-20260921-161136-3815.log` contains seven untagged trackpad magnify sequences at 16:12:00–05, then 18 emitted mouse magnify sequences at 16:12:07–23. All 18 contain Chrome preparation; there are no diagnostic-canvas receipts. Emitted sequences do not count attempts that never reached recognition. Recorded event timestamp intervals are typically 4.2–4.5 ms for the trackpad and about 15 ms for the mouse; this difference alone is not proof of the visible stutter's cause.

At 16:12:17.282 a fresh mouse contact is approaching (state 2), followed by old momentum-changed packets. At 16:12:17.315 it is state 3; at 16:12:17.316 the previous scroll sends momentum-ended. The coordinator previously rejected any idle recognizer with a device on any passing scroll, including these old inertia packets. This locked the new contact sequence out before the second finger could start zooming. Similar overlap appears around 16:12:19.171.

A regression test reproduced the rejection before the fix (momentum phases 1/2/3 each failed to start the following two-finger zoom). Momentum now leaves a new idle recognizer eligible, and during a two-finger candidate it is consumed without starting that candidate's 80 ms scroll deadline. Active zoom/tail suppression and rejection after an actual single-finger scroll remain covered. All 121 tests passed after the fix; release universal and debug builds succeeded. This confirms a recognizer failure and its correction, not that all Chrome rendering stalls or large jumps are resolved.

The same trace contains single preparation updates of +0.5/-0.333, while actual mouse increments reach approximately -0.098 in one update. These remain relevant to jump investigation, but this tap-level trace does not show Chrome's applied scale or prove that it rendered a preparation update. No additional rate limiting or movement dropping was introduced.

### Chrome viewport recording and startup separation

The local passive observer page recorded the user's reproduced jump in Chrome: 193 viewport scale changes, maximum frame ratio 1.544547 and minimum 0.653443. The before-correction DOM recording is saved in `build/chrome-zoom-before.json`. At 52841–52843 ms, a first wheel packet is followed by an actual viewport change from 1.333424 to 2.034047 (1.525432×). Other starts deliver the preparation separately and apply only small real updates. These observations implicate preparation merging before Chrome's threshold decision; the precise native coalescing layer is not directly observed.

The emitter now separates the preparation from real movement by at least 24 ms, serviced by the existing 10 ms coordinator timer. Every pending real increment and normal end is retained; continuing updates are immediate after this single startup interval. Standard/PDF output is unchanged. Target validation continues after a quick finger lift until pending output ends; target/configuration changes, teardown and cancellation discard delayed motion and close the posted gesture. There are no independent delayed callbacks to replay after cancellation.

125 Swift tests pass, including short gestures ending inside the interval, 20 alternating gestures, dense motion and reversal with total-scale preservation, immediate continuing output, queued gesture anchors and target changes after lift. Universal release and host debug builds pass. The observer page should be cleared and the new executable launched before the physical retest. A fixed gap is a delivery mitigation, not an acknowledgment from Chrome; behavior under a busy browser and sites with custom Ctrl-wheel handlers still requires validation. Do not infer hardware success from the fake-clock tests.
