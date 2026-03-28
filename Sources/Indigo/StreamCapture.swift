import ScreenCaptureKit
import CoreMedia
import AVFoundation

protocol StreamCaptureDelegate: AnyObject {
    func streamCapture(_ capture: StreamCapture, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer)
    func streamCapture(_ capture: StreamCapture, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer)
}

final class StreamCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    weak var delegate: StreamCaptureDelegate?

    private var stream: SCStream?

    var captureWidth: Int = 1920
    var captureHeight: Int = 1080
    var captureFPS: Int = 60
    var captureAudio: Bool = true
    var sourceRect: CGRect = .zero

    func startCapture() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        let pid = ProcessInfo.processInfo.processIdentifier

        guard let app = content.applications.first(where: { $0.processID == pid }) else {
            throw CaptureError.windowNotFound
        }

        guard let window = content.windows
            .filter({ $0.owningApplication?.processID == pid && $0.isOnScreen })
            .max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
        else {
            throw CaptureError.windowNotFound
        }

        NSLog("StreamCapture: window [%d] frame=%@", window.windowID, NSStringFromRect(window.frame))

        // Use application filter with only the main window included.
        // This captures audio from child processes (WKWebView's WebContent process)
        // while still scoping video to just our window.
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

        if sourceRect != .zero {
            config.sourceRect = sourceRect
            config.destinationRect = CGRect(x: 0, y: 0, width: captureWidth, height: captureHeight)
            NSLog("StreamCapture: sourceRect=%@, output=%dx%d",
                  NSStringFromRect(sourceRect), captureWidth, captureHeight)
        }

        let stream = SCStream(filter: filter, configuration: config, delegate: self)

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
        if captureAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        }

        try await stream.startCapture()
        self.stream = stream
        NSLog("StreamCapture: started OK (%dx%d @ %dfps, audio=%d)", captureWidth, captureHeight, captureFPS, captureAudio ? 1 : 0)
    }

    func stopCapture() async throws {
        try await stream?.stopCapture()
        stream = nil
    }

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

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("StreamCapture: error: %@", error.localizedDescription)
    }

    enum CaptureError: Error, LocalizedError {
        case windowNotFound
        var errorDescription: String? {
            "Could not find app window. Grant screen recording permission in System Settings."
        }
    }
}
