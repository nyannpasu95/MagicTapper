import Foundation
import IOKit
import IOKit.hidsystem

final class MouseSpeedIOKitBackend: MouseSpeedBackend {
    private let accelerationKey = "HIDMouseAcceleration" as CFString

    func readAcceleration() throws -> Double {
        let connection = try openHIDSystem()
        defer { IOServiceClose(connection) }

        var acceleration = 0.0
        let result = IOHIDGetAccelerationWithKey(connection, accelerationKey, &acceleration)
        guard result == KERN_SUCCESS else {
            throw MouseSpeedError.readFailed(kernelMessage(for: result))
        }

        return acceleration
    }

    func writeAcceleration(_ value: Double) throws {
        let connection = try openHIDSystem()
        defer { IOServiceClose(connection) }

        let result = IOHIDSetAccelerationWithKey(connection, accelerationKey, value)
        guard result == KERN_SUCCESS else {
            throw MouseSpeedError.writeFailed(kernelMessage(for: result))
        }
    }

    private func openHIDSystem() throws -> io_connect_t {
        let matchingDictionary = IOServiceMatching(kIOHIDSystemClass)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matchingDictionary)
        guard service != IO_OBJECT_NULL else {
            throw MouseSpeedError.backendUnavailable("IOHIDSystem service was not found.")
        }
        defer { IOObjectRelease(service) }

        var connection = io_connect_t()
        let result = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection)
        guard result == KERN_SUCCESS else {
            throw MouseSpeedError.backendUnavailable(kernelMessage(for: result))
        }

        return connection
    }

    private func kernelMessage(for result: kern_return_t) -> String {
        if let cString = mach_error_string(result) {
            return String(cString: cString)
        }

        return "Kernel error \(result)"
    }
}
