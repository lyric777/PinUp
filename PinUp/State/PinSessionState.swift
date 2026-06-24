import Foundation

enum PinSessionState: Equatable {
    case idle
    case resolvingTarget
    case startingCapture
    case pinned
    case failed(String)

    var isPinned: Bool {
        if case .pinned = self {
            return true
        }
        return false
    }

    var isWorking: Bool {
        switch self {
        case .resolvingTarget, .startingCapture:
            return true
        case .idle, .pinned, .failed:
            return false
        }
    }

    var summaryText: String {
        switch self {
        case .idle:
            return "Ready to Pin"
        case .resolvingTarget:
            return "Preparing Preview…"
        case .startingCapture:
            return "Connecting…"
        case .pinned:
            return "Pinned"
        case .failed:
            return "Action Needed"
        }
    }
}
