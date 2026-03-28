import SwiftUI
import WebKit

struct WebRendererView: NSViewRepresentable {
    let url: String
    let onWebViewReady: (WKWebView) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        onWebViewReady(webView)
        if let url = URL(string: url) {
            webView.load(URLRequest(url: url))
        }
        context.coordinator.lastLoadedURL = url
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: url) else { return }
        if context.coordinator.lastLoadedURL != self.url {
            context.coordinator.lastLoadedURL = self.url
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedURL: String?

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            print("WebContent process terminated, reloading...")
            webView.reload()
        }
    }
}
