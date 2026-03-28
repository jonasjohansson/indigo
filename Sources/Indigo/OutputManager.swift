import Metal
import CoreMedia
import ScreenCaptureKit
import AppKit

final class OutputManager: ObservableObject, StreamCaptureDelegate {
    let streamCapture = StreamCapture()
    let syphonOutput: SyphonOutput
    let ndiOutput = NDIOutput()

    private let device: MTLDevice
    private var captureWindow: CaptureWindow?

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

    func startCapture(settings: AppSettings, currentURL: String) async {
        streamCapture.captureWidth = settings.resolution.width
        streamCapture.captureHeight = settings.resolution.height
        streamCapture.captureFPS = settings.fps
        streamCapture.captureAudio = settings.audioEnabled

        // Create offscreen capture window at target resolution
        let cw = await MainActor.run {
            let cw = CaptureWindow(width: settings.resolution.width, height: settings.resolution.height)
            cw.loadURL(currentURL)
            return cw
        }
        self.captureWindow = cw

        if settings.syphonEnabled {
            syphonOutput.start(name: "Indigo")
        }
        if settings.ndiEnabled {
            ndiOutput.start(name: "Indigo")
        }

        // Small delay to let the window appear in the window server
        try? await Task.sleep(nanoseconds: 500_000_000)

        do {
            let windowID = await MainActor.run { CGWindowID(cw.window.windowNumber) }
            try await streamCapture.startCapture(windowID: windowID)
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
            await MainActor.run { cw.close() }
            self.captureWindow = nil
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
            captureWindow?.close()
            captureWindow = nil
            isCapturing = false
        }
    }

    /// Forward URL changes to the capture window
    func updateCaptureURL(_ url: String) {
        captureWindow?.loadURL(url)
    }

    /// Forward navigation to the capture window
    func captureGoBack() { captureWindow?.goBack() }
    func captureGoForward() { captureWindow?.goForward() }
    func captureReload() { captureWindow?.reload() }

    // MARK: - StreamCaptureDelegate

    func streamCapture(_ capture: StreamCapture, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
        syphonOutput.publishFrame(from: sampleBuffer)
        ndiOutput.sendVideoFrame(from: sampleBuffer)
    }

    func streamCapture(_ capture: StreamCapture, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer) {
        ndiOutput.sendAudioFrame(from: sampleBuffer)
    }
}
