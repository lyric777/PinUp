import CoreGraphics
import Foundation

struct WindowMatcher {
    func matchWindow(
        pid: pid_t,
        appName: String,
        focusedWindowTitle: String,
        focusedWindowFrame: CGRect
    ) -> TargetWindowDescriptor? {
        guard let rawWindowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let candidates = rawWindowList.compactMap(CGWindowCandidate.init(dictionary:))
            .filter { candidate in
                candidate.ownerPID == pid &&
                candidate.layer == 0 &&
                candidate.alpha > 0.01 &&
                candidate.bounds.width > 48 &&
                candidate.bounds.height > 48
            }

        let normalizedTitle = focusedWindowTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedOwner = appName.lowercased()

        let bestCandidate = candidates
            .map { candidate in
                (candidate, score(candidate: candidate, title: normalizedTitle, owner: normalizedOwner, frame: focusedWindowFrame))
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.bounds.width * lhs.0.bounds.height > rhs.0.bounds.width * rhs.0.bounds.height
                }
                return lhs.1 > rhs.1
            }
            .first

        guard let candidate = bestCandidate?.0 else {
            return nil
        }

        let resolvedTitle = candidate.windowName.isEmpty ? focusedWindowTitle : candidate.windowName
        return TargetWindowDescriptor(
            id: "\(candidate.ownerPID)-\(candidate.windowID)",
            pid: candidate.ownerPID,
            appName: candidate.ownerName.isEmpty ? appName : candidate.ownerName,
            windowTitle: resolvedTitle,
            frame: candidate.bounds,
            cgWindowID: candidate.windowID
        )
    }

    private func score(candidate: CGWindowCandidate, title: String, owner: String, frame: CGRect) -> Int {
        var score = 0
        let candidateTitle = candidate.windowName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidateOwner = candidate.ownerName.lowercased()

        if !title.isEmpty {
            if candidateTitle == title {
                score += 120
            } else if candidateTitle.contains(title) || title.contains(candidateTitle) {
                score += 70
            }
        }

        if candidateOwner == owner {
            score += 25
        }

        if !frame.equalTo(.zero) {
            let distance = hypot(candidate.bounds.midX - frame.midX, candidate.bounds.midY - frame.midY)
            score += max(0, 80 - Int(distance / 12))

            let areaDelta = abs((candidate.bounds.width * candidate.bounds.height) - (frame.width * frame.height))
            score += max(0, 40 - Int(areaDelta / 1_000))
        }

        return score
    }
}

private struct CGWindowCandidate {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let windowName: String
    let bounds: CGRect
    let layer: Int
    let alpha: Double

    init?(dictionary: [String: Any]) {
        guard
            let windowNumber = dictionary[kCGWindowNumber as String] as? NSNumber,
            let ownerPID = dictionary[kCGWindowOwnerPID as String] as? NSNumber,
            let ownerName = dictionary[kCGWindowOwnerName as String] as? String,
            let boundsDictionary = dictionary[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
        else {
            return nil
        }

        self.windowID = CGWindowID(windowNumber.uint32Value)
        self.ownerPID = ownerPID.int32Value
        self.ownerName = ownerName
        self.windowName = dictionary[kCGWindowName as String] as? String ?? ""
        self.bounds = bounds
        self.layer = dictionary[kCGWindowLayer as String] as? Int ?? 0
        self.alpha = dictionary[kCGWindowAlpha as String] as? Double ?? 1.0
    }
}
