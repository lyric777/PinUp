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
            return L10n.tr("ready_to_pin")
        case .resolvingTarget:
            return L10n.tr("preparing_preview")
        case .startingCapture:
            return L10n.tr("connecting")
        case .pinned:
            return L10n.tr("pinned")
        case .failed:
            return L10n.tr("action_needed")
        }
    }
}
