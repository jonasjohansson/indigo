import Metal
import CoreMedia
import ScreenCaptureKit
import AppKit

final class OutputManager: ObservableObject, StreamCaptureDelegate {
    let streamCapture = StreamCapture()
    let syphonOutput: SyphonOutput
    let ndiOutput = NDIOutput()

    private let device: MTLDevice
    private var frameCount = 0
    private var isStopping = false

    @Published var isCapturing = false
    @Published var error: String?

    /// Set by ContentView — the WKWebView reference for getting its frame
    weak var webViewStore: WebViewStore?

    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not available on this system")
        }
        self.device = device
        self.syphonOutput = SyphonOutput(device: device)
        streamCapture.delegate = self
    }

    func startCapture(settings: AppSettings) async {
        guard !isCapturing && !isStopping else { return }
        NSLog("OutputManager: startCapture called")

        streamCapture.captureWidth = settings.width
        streamCapture.captureHeight = settings.height
        streamCapture.captureFPS = settings.fps
        streamCapture.captureAudio = settings.audioEnabled

        // Get the web view's rect within the window (in points)
        let rect = await MainActor.run { () -> CGRect in
            guard let webView = webViewStore?.webView,
                  let window = webView.window else { return .zero }

            // Convert web view bounds to window coordinates
            let rectInWindow = webView.convert(webView.bounds, to: nil)
            // ScreenCaptureKit sourceRect uses top-left origin
            let windowHeight = window.frame.height
            let topLeftRect = CGRect(
                x: rectInWindow.origin.x,
                y: windowHeight - rectInWindow.origin.y - rectInWindow.height,
                width: rectInWindow.width,
                height: rectInWindow.height
            )
            NSLog("OutputManager: webView bounds=%@, inWindow=%@, sourceRect=%@",
                  NSStringFromRect(webView.bounds),
                  NSStringFromRect(rectInWindow),
                  NSStringFromRect(topLeftRect))
            return topLeftRect
        }

        if rect != .zero {
            streamCapture.sourceRect = rect
        }

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
            NSLog("OutputManager: capture running")
        } catch {
            NSLog("OutputManager: FAILED: %@", error.localizedDescription)
            await MainActor.run {
                self.error = error.localizedDescription
                isCapturing = false
            }
            syphonOutput.stop()
            ndiOutput.stop()
        }
    }

    func stopCapture() async {
        guard isCapturing && !isStopping else { return }
        isStopping = true
        streamCapture.delegate = nil

        do {
            try await streamCapture.stopCapture()
        } catch {
            NSLog("OutputManager: stop error: %@", error.localizedDescription)
        }

        syphonOutput.stop()
        ndiOutput.stop()
        frameCount = 0
        streamCapture.sourceRect = .zero
        streamCapture.delegate = self

        await MainActor.run {
            isCapturing = false
            isStopping = false
        }
    }

    // MARK: - StreamCaptureDelegate

    func streamCapture(_ capture: StreamCapture, didOutputVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
        guard !isStopping else { return }
        frameCount += 1
        if frameCount <= 5 || frameCount % 300 == 0 {
            NSLog("OutputManager: frame #%d", frameCount)
        }
        syphonOutput.publishFrame(from: sampleBuffer)
        ndiOutput.sendVideoFrame(from: sampleBuffer)
    }

    func streamCapture(_ capture: StreamCapture, didOutputAudioSampleBuffer sampleBuffer: CMSampleBuffer) {
        guard !isStopping else { return }
        ndiOutput.sendAudioFrame(from: sampleBuffer)
    }
}
