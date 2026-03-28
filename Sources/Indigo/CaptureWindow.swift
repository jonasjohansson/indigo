import AppKit
import WebKit

/// A borderless offscreen window containing a WKWebView at the exact output resolution.
/// This window is what ScreenCaptureKit captures — only the web content, no UI chrome.
final class CaptureWindow {
    let window: NSWindow
    let webView: WKWebView
    private var currentURL: String?

    init(width: Int, height: Int) {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height), configuration: config)
        webView.autoresizingMask = [.width, .height]

        // Create a borderless window positioned off-screen but still composited
        // (macOS throttles rendering of non-composited windows)
        window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: width, height: height),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.title = "Indigo Capture"
        window.backgroundColor = .black
        // Order it behind everything so it's composited but not visible
        window.orderBack(nil)
    }

    func loadURL(_ urlString: String) {
        guard urlString != currentURL else { return }
        currentURL = urlString
        guard let url = URL(string: urlString) else { return }
        webView.load(URLRequest(url: url))
    }

    func resize(width: Int, height: Int) {
        window.setContentSize(NSSize(width: width, height: height))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }

    func close() {
        window.orderOut(nil)
    }
}
