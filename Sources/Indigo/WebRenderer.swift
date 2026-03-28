import SwiftUI
import WebKit

class WebViewStore: ObservableObject {
    @Published var webView: WKWebView?

    func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        webView?.load(URLRequest(url: url))
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
}

struct WebRendererView: NSViewRepresentable {
    @ObservedObject var store: WebViewStore
    let url: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        DispatchQueue.main.async {
            store.webView = webView
        }

        if let url = URL(string: url) {
            webView.load(URLRequest(url: url))
        }
        context.coordinator.lastLoadedURL = url
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastLoadedURL != url {
            context.coordinator.lastLoadedURL = url
            if let parsed = URL(string: url) {
                webView.load(URLRequest(url: parsed))
            }
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
