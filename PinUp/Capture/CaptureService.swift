import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ScreenCaptureKit

private let pinUpCIContext = CIContext()

@MainActor
final class CaptureService: NSObject {
    var onFrame: ((CGImage?) -> Void)?
    var onFailure: ((String) -> Void)?

    private var stream: SCStream?
    private let frameQueue = DispatchQueue(label: "PinUp.Capture.FrameQueue")
    func startCapture(for target: TargetWindowDescriptor) async throws {
        await stopCapture()

        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let shareableWindow = shareableContent.windows.first(where: { $0.windowID == target.cgWindowID }) else {
            throw PinUpError.captureWindowUnavailable
        }

        let filter = SCContentFilter(desktopIndependentWindow: shareableWindow)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(max(target.frame.width, 320))
        configuration.height = Int(max(target.frame.height, 200))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.queueDepth = 3

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: frameQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stopCapture() async {
        if let stream {
            try? await stream.stopCapture()
        }

        self.stream = nil
        onFrame?(nil)
    }

    nonisolated private static func makeImage(from sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return pinUpCIContext.createCGImage(ciImage, from: ciImage.extent)
    }
}

extension CaptureService: SCStreamOutput, SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen else {
            return
        }

        let frameImage = Self.makeImage(from: sampleBuffer)
        Task { @MainActor in
            self.onFrame?(frameImage)
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.onFailure?(error.localizedDescription)
        }
    }
}
