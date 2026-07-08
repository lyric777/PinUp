import Foundation
import os

enum PinUpDebugLogger {
    private static let logger = Logger(subsystem: "com.pinup.app", category: "debug")
    private static let lock = NSLock()
    private nonisolated(unsafe) static var recentMessages: [String] = []
    private static let maxRecentMessageCount = 500

    static func log(_ message: @autoclosure () -> String) {
        let resolvedMessage = "[PinUp] \(message())"
        appendRecentMessage(resolvedMessage)
        logger.debug("\(resolvedMessage, privacy: .public)")

        #if DEBUG
        print(resolvedMessage)
        #endif
    }

    static func recentLogText() -> String {
        lock.lock()
        defer {
            lock.unlock()
        }

        return recentMessages.joined(separator: "\n")
    }

    private static func appendRecentMessage(_ message: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        recentMessages.append(message)
        if recentMessages.count > maxRecentMessageCount {
            recentMessages.removeFirst(recentMessages.count - maxRecentMessageCount)
        }
    }
}
