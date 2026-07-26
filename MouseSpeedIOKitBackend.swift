import Foundation
import IOKit
import IOKit.hidsystem

final class MouseSpeedIOKitBackend: MouseSpeedBackend {
    private let accelerationKey = "HIDMouseAcceleration" as CFString

    // Lazily opened and cached. The slider is `isContinuous`, so each drag tick
    // would otherwise open/close the IOHIDSystem service — a kernel round-trip
    // per tick. We hold the connection for the lifetime of the backend instead.
    private var cachedConnection: io_connect_t?
    private var openError: Error?

    init() {}

    deinit {
        if let connection = cachedConnection {
            IOServiceClose(connection)
        }
    }

    func readAcceleration() throws -> Double {
        let connection = try openHIDSystem()

        var acceleration = 0.0
        let result = IOHIDGetAccelerationWithKey(connection, accelerationKey, &acceleration)
        guard result == KERN_SUCCESS else {
            throw MouseSpeedError.readFailed(kernelMessage(for: result))
        }

        return acceleration
    }

    func writeAcceleration(_ value: Double) throws {
        let connection = try openHIDSystem()

        let result = IOHIDSetAccelerationWithKey(connection, accelerationKey, value)
        guard result == KERN_SUCCESS else {
            throw MouseSpeedError.writeFailed(kernelMessage(for: result))
        }
    }

    private func openHIDSystem() throws -> io_connect_t {
        // If a previous open attempt failed, surface that error consistently
        // rather than retrying the (slow) service lookup on every call.
        if let openError = openError {
            throw openError
        }
        if let connection = cachedConnection {
            return connection
        }

        let matchingDictionary = IOServiceMatching(kIOHIDSystemClass)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matchingDictionary)
        guard service != IO_OBJECT_NULL else {
            let error = MouseSpeedError.backendUnavailable("IOHIDSystem service was not found.")
            openError = error
            throw error
        }
        defer { IOObjectRelease(service) }

        var connection = io_connect_t()
        let result = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection)
        guard result == KERN_SUCCESS else {
            let error = MouseSpeedError.backendUnavailable(kernelMessage(for: result))
            openError = error
            throw error
        }

        cachedConnection = connection
        return connection
    }

    private func kernelMessage(for result: kern_return_t) -> String {
        if let cString = mach_error_string(result) {
            return String(cString: cString)
        }

        return "Kernel error \(result)"
    }
}
