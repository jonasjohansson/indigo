import Metal
import CoreMedia
import ScreenCaptureKit

final class OutputManager: ObservableObject, StreamCaptureDelegate {
    let streamCapture = StreamCapture()
    let syphonOutput: SyphonOutput
    let ndiOutput = NDIOutput()

    private let device: MTLDevice

    @Published var isCapturing = false
    @Published var error: String?

    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not available on this system")
        }
        self.device = device
        self.syphonOutput = SyphonOutput(device: device)
        streamCapture.delegate = self
    }

    func startCapture(settings: AppSettings) async {
        streamCapture.captureWidth = settings.resolution.width
        streamCapture.captureHeight = settings.resolution.height
        streamCapture.captureFPS = settings.fps
        streamCapture.captureAudio = settings.audioEnabled

        if settings.syphonEnabled {
            syphonOutput.start(name: "Indigo")
        }
        if settings.ndiEnabled {
            ndiOutput.start(name: "Indigo")
        }

        do {
            try await streamCapture.startCapture()
            await MainActor.run {
                isCapturing = true
                error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isCapturing = false
            }
            syphonOutput.stop()
            ndiOutput.stop()
        }
    }

    func stopCapture() async {
        do {
            try await streamCapture.stopCapture()
        } catch {
            print("Error stopping capture: \(error)")
        }
        syphonOutput.stop()
        ndiOutput.stop()

        await MainActor.run {
            isCapturing = false
        }
    }

    // MARK: - StreamCaptureDelegate

    func streamCapture(_ capture: StreamCapture, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
        syphonOutput.publishFrame(from: sampleBuffer)
        ndiOutput.sendVideoFrame(from: sampleBuffer)
    }

    func streamCapture(_ capture: StreamCapture, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer) {
        ndiOutput.sendAudioFrame(from: sampleBuffer)
    }
}
