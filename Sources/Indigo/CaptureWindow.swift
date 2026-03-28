import AppKit
import WebKit

/// A borderless offscreen window containing a WKWebView at the exact output resolution.
/// This window is what ScreenCaptureKit captures — only the web content, no UI chrome.
final class CaptureWindow: NSObject, WKNavigationDelegate {
    let window: NSWindow
    let webView: WKWebView
    private var currentURL: String?
    private var customCSS: String?

    init(width: Int, height: Int, customCSS: String? = nil) {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Inject custom CSS via user script if provided
        if let css = customCSS, !css.isEmpty {
            let cssEscaped = css.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            let js = """
            (function() {
                var style = document.createElement('style');
                style.textContent = '\(cssEscaped)';
                document.head.appendChild(style);
            })();
            """
            let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            config.userContentController.addUserScript(script)
        }

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height), configuration: config)
        webView.autoresizingMask = [.width, .height]
        self.customCSS = customCSS

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
        window.orderBack(nil)

        super.init()
        webView.navigationDelegate = self
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

    func refreshCache() {
        guard let url = webView.url else {
            webView.reload()
            return
        }
        // Clear cache then reload
        let dataStore = WKWebsiteDataStore.default()
        dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            self?.webView.load(URLRequest(url: url))
        }
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }

    func close() {
        window.orderOut(nil)
    }

    // Re-inject CSS after navigation
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        injectCSS()
    }

    private func injectCSS() {
        guard let css = customCSS, !css.isEmpty else { return }
        let cssEscaped = css.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let js = """
        (function() {
            var existing = document.getElementById('indigo-custom-css');
            if (existing) existing.remove();
            var style = document.createElement('style');
            style.id = 'indigo-custom-css';
            style.textContent = '\(cssEscaped)';
            document.head.appendChild(style);
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
