import ScreenCaptureKit
import CoreMedia
import AVFoundation

protocol StreamCaptureDelegate: AnyObject {
    func streamCapture(_ capture: StreamCapture, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer)
    func streamCapture(_ capture: StreamCapture, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer)
}

final class StreamCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    weak var delegate: StreamCaptureDelegate?

    private var videoStream: SCStream?
    private var audioStream: SCStream?

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

        // --- Video stream: window filter with sourceRect crop ---
        let videoFilter = SCContentFilter(desktopIndependentWindow: window)

        let videoConfig = SCStreamConfiguration()
        videoConfig.width = captureWidth
        videoConfig.height = captureHeight
        videoConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(captureFPS))
        videoConfig.pixelFormat = kCVPixelFormatType_32BGRA
        videoConfig.showsCursor = false
        videoConfig.capturesAudio = false

        if sourceRect != .zero {
            videoConfig.sourceRect = sourceRect
            videoConfig.destinationRect = CGRect(x: 0, y: 0, width: captureWidth, height: captureHeight)
            NSLog("StreamCapture: video sourceRect=%@, output=%dx%d",
                  NSStringFromRect(sourceRect), captureWidth, captureHeight)
        }

        let vStream = SCStream(filter: videoFilter, configuration: videoConfig, delegate: self)
        try vStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
        try await vStream.startCapture()
        self.videoStream = vStream
        NSLog("StreamCapture: video started (%dx%d @ %dfps)", captureWidth, captureHeight, captureFPS)

        // --- Audio stream: display filter to capture child process audio ---
        if captureAudio {
            guard let display = content.displays.first else {
                NSLog("StreamCapture: no display found for audio, skipping")
                return
            }

            let otherApps = content.applications.filter { $0.processID != pid }
            let audioFilter = SCContentFilter(display: display, excludingApplications: otherApps, exceptingWindows: [])

            let audioConfig = SCStreamConfiguration()
            audioConfig.width = 2  // minimal — we don't use the video from this stream
            audioConfig.height = 2
            audioConfig.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1fps video (ignored)
            audioConfig.capturesAudio = true
            audioConfig.sampleRate = 48000
            audioConfig.channelCount = 2

            let aStream = SCStream(filter: audioFilter, configuration: audioConfig, delegate: self)
            try aStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
            try await aStream.startCapture()
            self.audioStream = aStream
            NSLog("StreamCapture: audio started (48kHz stereo)")
        }
    }

    func stopCapture() async throws {
        if let vs = videoStream {
            try await vs.stopCapture()
            videoStream = nil
        }
        if let as_ = audioStream {
            try await as_.stopCapture()
            audioStream = nil
        }
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        switch type {
        case .screen:
            // Only forward video from the video stream (not the tiny audio stream video)
            if stream === videoStream {
                delegate?.streamCapture(self, didOutputVideoSampleBuffer: sampleBuffer)
            }
        case .audio, .microphone:
            delegate?.streamCapture(self, didOutputAudioSampleBuffer: sampleBuffer)
        @unknown default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("StreamCapture: stream error: %@", error.localizedDescription)
    }

    enum CaptureError: Error, LocalizedError {
        case windowNotFound
        var errorDescription: String? {
            "Could not find app window. Grant screen recording permission in System Settings."
        }
    }
}
