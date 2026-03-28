import ScreenCaptureKit
import CoreMedia
import AVFoundation

protocol StreamCaptureDelegate: AnyObject {
    func streamCapture(_ capture: StreamCapture, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer)
    func streamCapture(_ capture: StreamCapture, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer)
}

final class StreamCapture: NSObject, SCStreamOutput {
    weak var delegate: StreamCaptureDelegate?

    private var stream: SCStream?

    var captureWidth: Int = 1920
    var captureHeight: Int = 1080
    var captureFPS: Int = 60
    var captureAudio: Bool = true

    /// Start capturing a specific window (the offscreen capture window)
    func startCapture(windowID: CGWindowID) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let window = content.windows.first(where: {
            $0.windowID == windowID
        }) else {
            throw CaptureError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)

        let config = SCStreamConfiguration()
        config.width = captureWidth
        config.height = captureHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(captureFPS))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = captureAudio
        config.sampleRate = 48000
        config.channelCount = 2

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
        if captureAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        }

        try await stream.startCapture()
        self.stream = stream
    }

    func stopCapture() async throws {
        try await stream?.stopCapture()
        stream = nil
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        switch type {
        case .screen:
            delegate?.streamCapture(self, didOutputVideoSampleBuffer: sampleBuffer)
        case .audio, .microphone:
            delegate?.streamCapture(self, didOutputAudioSampleBuffer: sampleBuffer)
        @unknown default:
            break
        }
    }

    enum CaptureError: Error, LocalizedError {
        case windowNotFound

        var errorDescription: String? {
            switch self {
            case .windowNotFound:
                return "Could not find the capture window. Make sure screen recording permission is granted."
            }
        }
    }
}
