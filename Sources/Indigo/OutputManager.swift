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
    private var frameCount = 0

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
        streamCapture.captureWidth = settings.width
        streamCapture.captureHeight = settings.height
        streamCapture.captureFPS = settings.fps
        streamCapture.captureAudio = settings.audioEnabled

        // Create the capture window on the main thread
        let cw = await MainActor.run {
            let cw = CaptureWindow(
                width: settings.width,
                height: settings.height,
                customCSS: settings.customCSS
            )
            cw.loadURL(settings.url)
            return cw
        }
        self.captureWindow = cw

        if settings.syphonEnabled {
            syphonOutput.start(name: "Indigo")
        }
        if settings.ndiEnabled {
            ndiOutput.start(name: "Indigo")
        }

        // Give the window time to appear in the window server
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        do {
            let windowID = await MainActor.run { CGWindowID(cw.window.windowNumber) }
            NSLog("OutputManager: starting capture of window %d", windowID)
            try await streamCapture.startCapture(windowID: windowID)
            await MainActor.run {
                isCapturing = true
                error = nil
            }
        } catch {
            NSLog("OutputManager: capture failed: %@", error.localizedDescription)
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
            NSLog("OutputManager: error stopping: %@", error.localizedDescription)
        }
        syphonOutput.stop()
        ndiOutput.stop()
        frameCount = 0

        await MainActor.run {
            captureWindow?.close()
            captureWindow = nil
            isCapturing = false
        }
    }

    func updateCaptureURL(_ url: String) {
        captureWindow?.loadURL(url)
    }

    func captureGoBack() { captureWindow?.goBack() }
    func captureGoForward() { captureWindow?.goForward() }
    func captureReload() { captureWindow?.reload() }
    func captureRefreshCache() { captureWindow?.refreshCache() }

    // MARK: - StreamCaptureDelegate

    func streamCapture(_ capture: StreamCapture, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
        frameCount += 1
        if frameCount <= 3 || frameCount % 300 == 0 {
            NSLog("OutputManager: video frame #%d", frameCount)
        }
        syphonOutput.publishFrame(from: sampleBuffer)
        ndiOutput.sendVideoFrame(from: sampleBuffer)
    }

    func streamCapture(_ capture: StreamCapture, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer) {
        ndiOutput.sendAudioFrame(from: sampleBuffer)
    }
}
