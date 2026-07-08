import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ScreenCaptureKit

private let pinUpCIContext = CIContext()
private let pinUpCropState = CaptureCropState()

private final class CaptureCropState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedTargetPixelSize: CGSize?

    var targetPixelSize: CGSize? {
        get {
            lock.lock()
            defer {
                lock.unlock()
            }

            return storedTargetPixelSize
        }

        set {
            lock.lock()
            storedTargetPixelSize = newValue
            lock.unlock()
        }
    }
}

@MainActor
final class CaptureService: NSObject {
    var onFrame: ((CGImage?) -> Void)?
    var onFailure: ((String) -> Void)?

    private var stream: SCStream?
    private let frameQueue = DispatchQueue(label: "PinUp.Capture.FrameQueue")
    private var sampleBufferCount = 0
    private var imageFrameCount = 0
    private var currentCaptureScale: CGFloat = 1
    private var isStoppingIntentionally = false

    func startCapture(for target: TargetWindowDescriptor) async throws {
        await stopCapture()
        sampleBufferCount = 0
        imageFrameCount = 0
        isStoppingIntentionally = false

        PinUpDebugLogger.log("Starting capture for target: \(target.debugSummary)")

        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let relatedWindows = shareableContent.windows.filter { window in
            window.windowID == target.cgWindowID || window.owningApplication?.processID == target.pid
        }
        PinUpDebugLogger.log("ScreenCaptureKit related windows: \(relatedWindows.map(\.debugSummary).joined(separator: " | "))")

        guard let shareableWindow = shareableContent.windows.first(where: { $0.windowID == target.cgWindowID }) else {
            PinUpDebugLogger.log("ScreenCaptureKit could not find target cgWindowID=\(target.cgWindowID)")
            throw PinUpError.captureWindowUnavailable
        }

        let filter = SCContentFilter(desktopIndependentWindow: shareableWindow)
        let configuration = SCStreamConfiguration()
        let captureScale = Self.captureScale(for: shareableWindow.frame)
        currentCaptureScale = captureScale
        let targetPixelSize = CGSize(
            width: target.frame.width * captureScale,
            height: target.frame.height * captureScale
        )
        pinUpCropState.targetPixelSize = targetPixelSize
        configuration.width = Int(max(targetPixelSize.width, 320))
        configuration.height = Int(max(targetPixelSize.height, 200))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.scalesToFit = false
        let sourceRect = Self.sourceRect(targetFrame: target.frame, shareableFrame: shareableWindow.frame)
        configuration.sourceRect = sourceRect
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.queueDepth = 3

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: frameQueue)
        try await stream.startCapture()
        self.stream = stream
        PinUpDebugLogger.log("ScreenCaptureKit stream started: windowID=\(shareableWindow.windowID), scale=\(String(format: "%.1f", captureScale)), size=\(configuration.width)x\(configuration.height), sourceRect=\(sourceRect.debugSummary), targetFrame=\(target.frame.debugSummary), shareableFrame=\(shareableWindow.frame.debugSummary)")
    }

    func stopCapture() async {
        if let stream {
            isStoppingIntentionally = true
            try? await stream.stopCapture()
        }

        self.stream = nil
        if sampleBufferCount > 0 || imageFrameCount > 0 {
            PinUpDebugLogger.log("Capture stopped after sampleBuffers=\(sampleBufferCount), imageFrames=\(imageFrameCount)")
        }
        onFrame?(nil)
        pinUpCropState.targetPixelSize = nil
    }

    private func handleFrame(_ frameImage: CGImage?, sampleBufferIsValid: Bool) {
        sampleBufferCount += 1

        if frameImage != nil {
            imageFrameCount += 1
            if imageFrameCount == 1 {
                PinUpDebugLogger.log("First capture frame arrived after sampleBuffers=\(sampleBufferCount)")
            }
        } else if sampleBufferCount <= 3 {
            PinUpDebugLogger.log("Sample buffer did not produce an image: count=\(sampleBufferCount), valid=\(sampleBufferIsValid)")
        }

        guard let frameImage else {
            return
        }

        onFrame?(frameImage)
    }

    nonisolated private static func makeImage(from sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let cropRect = Self.captureCropRect(in: pixelBuffer) ?? ciImage.extent
        return pinUpCIContext.createCGImage(ciImage.cropped(to: cropRect), from: cropRect)
    }

    private static func captureScale(for frame: CGRect) -> CGFloat {
        NSScreen.screens.first { screen in
            screen.frame.intersects(frame)
        }?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
    }

    private static func sourceRect(targetFrame: CGRect, shareableFrame: CGRect) -> CGRect {
        let relativeRect = CGRect(
            x: max(0, targetFrame.minX - shareableFrame.minX),
            y: max(0, targetFrame.minY - shareableFrame.minY),
            width: min(targetFrame.width, shareableFrame.width),
            height: min(targetFrame.height, shareableFrame.height)
        )

        guard relativeRect.width > 0, relativeRect.height > 0 else {
            return CGRect(origin: .zero, size: shareableFrame.size)
        }

        return relativeRect
    }

    nonisolated private static func captureCropRect(in pixelBuffer: CVPixelBuffer) -> CGRect? {
        let visibleRect = visibleContentRect(in: pixelBuffer)
        return targetSizedCropRect(in: pixelBuffer, fallbackRect: visibleRect) ?? visibleRect
    }

    nonisolated private static func targetSizedCropRect(in pixelBuffer: CVPixelBuffer, fallbackRect: CGRect?) -> CGRect? {
        guard let targetPixelSize = pinUpCropState.targetPixelSize else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let targetWidth = Int(targetPixelSize.width.rounded())
        let targetHeight = Int(targetPixelSize.height.rounded())

        guard targetWidth > 0, targetHeight > 0 else {
            return nil
        }

        let cropWidth = min(width, targetWidth)
        let cropHeight = min(height, targetHeight)
        guard width - cropWidth > 2 || height - cropHeight > 2 else {
            return nil
        }

        let fallback = fallbackRect ?? CGRect(x: 0, y: 0, width: width, height: height)
        let cropRect = CGRect(
            x: fallback.minX,
            y: fallback.maxY - CGFloat(cropHeight),
            width: CGFloat(cropWidth),
            height: CGFloat(cropHeight)
        )

        PinUpDebugLogger.log("Target-cropped capture frame from \(width)x\(height) to \(cropWidth)x\(cropHeight)")
        return cropRect
    }

    nonisolated private static func visibleContentRect(in pixelBuffer: CVPixelBuffer) -> CGRect? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        let step = max(1, min(width, height) / 240)

        func hasVisiblePixel(inRow y: Int) -> Bool {
            var x = 0
            while x < width {
                if isVisiblePixel(bytes: bytes, bytesPerRow: bytesPerRow, x: x, y: y) {
                    return true
                }
                x += step
            }
            return false
        }

        func hasVisiblePixel(inColumn x: Int, from minY: Int, to maxY: Int) -> Bool {
            var y = minY
            while y <= maxY {
                if isVisiblePixel(bytes: bytes, bytesPerRow: bytesPerRow, x: x, y: y) {
                    return true
                }
                y += step
            }
            return false
        }

        var minY = 0
        while minY < height, !hasVisiblePixel(inRow: minY) {
            minY += 1
        }

        var maxY = height - 1
        while maxY > minY, !hasVisiblePixel(inRow: maxY) {
            maxY -= 1
        }

        var minX = 0
        while minX < width, !hasVisiblePixel(inColumn: minX, from: minY, to: maxY) {
            minX += 1
        }

        var maxX = width - 1
        while maxX > minX, !hasVisiblePixel(inColumn: maxX, from: minY, to: maxY) {
            maxX -= 1
        }

        let cropWidth = maxX - minX + 1
        let cropHeight = maxY - minY + 1
        guard cropWidth > width / 4, cropHeight > height / 4 else {
            return nil
        }

        let croppedAwayPixels = (width * height) - (cropWidth * cropHeight)
        if croppedAwayPixels > 0 {
            PinUpDebugLogger.log("Cropped capture frame from \(width)x\(height) to \(cropWidth)x\(cropHeight)")
        }

        return CGRect(x: minX, y: height - maxY - 1, width: cropWidth, height: cropHeight)
    }

    nonisolated private static func isVisiblePixel(bytes: UnsafePointer<UInt8>, bytesPerRow: Int, x: Int, y: Int) -> Bool {
        let offset = y * bytesPerRow + x * 4
        let blue = Int(bytes[offset])
        let green = Int(bytes[offset + 1])
        let red = Int(bytes[offset + 2])
        let alpha = Int(bytes[offset + 3])

        guard alpha > 8 else {
            return false
        }

        return red > 10 || green > 10 || blue > 10
    }
}

extension CaptureService: SCStreamOutput, SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen else {
            return
        }

        let frameImage = Self.makeImage(from: sampleBuffer)
        let sampleBufferIsValid = CMSampleBufferIsValid(sampleBuffer)
        Task { @MainActor in
            self.handleFrame(frameImage, sampleBufferIsValid: sampleBufferIsValid)
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            guard !self.isStoppingIntentionally else {
                PinUpDebugLogger.log("ScreenCaptureKit stream stopped during intentional stop: \(error.localizedDescription)")
                self.isStoppingIntentionally = false
                return
            }

            PinUpDebugLogger.log("ScreenCaptureKit stream stopped with error: \(error.localizedDescription)")
            self.onFailure?(error.localizedDescription)
        }
    }
}

private extension SCWindow {
    var debugSummary: String {
        let appName = owningApplication?.applicationName ?? "<unknown app>"
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let titleSummary = trimmedTitle.isEmpty ? "<empty>" : trimmedTitle
        return "id=\(windowID), app=\(appName), title=\(titleSummary), frame=\(frame.debugSummary)"
    }
}

private extension CGRect {
    var debugSummary: String {
        "x=\(Int(origin.x)), y=\(Int(origin.y)), w=\(Int(width)), h=\(Int(height))"
    }
}
