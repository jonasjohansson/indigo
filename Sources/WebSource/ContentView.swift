import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @ObservedObject var outputManager: OutputManager
    @State private var urlInput: String = ""
    @State private var webView: WKWebView?

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack(spacing: 8) {
                Button(action: { webView?.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!(webView?.canGoBack ?? false))

                Button(action: { webView?.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!(webView?.canGoForward ?? false))

                Button(action: { webView?.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }

                TextField("URL", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
                        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
                            urlInput = "https://" + trimmed
                        }
                        settings.url = urlInput
                    }
            }
            .padding(8)

            // Web view
            WebRendererView(url: settings.url) { wv in
                self.webView = wv
            }

            Divider()

            // Control strip
            HStack(spacing: 16) {
                // Resolution picker
                Picker("", selection: $settings.resolution) {
                    ForEach(Resolution.presets) { res in
                        Text(res.label).tag(res)
                    }
                }
                .labelsHidden()
                .frame(width: 140)

                // FPS picker
                Picker("", selection: $settings.fps) {
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }
                .labelsHidden()
                .frame(width: 90)

                Spacer()

                // Output toggles
                Toggle("Syphon", isOn: $settings.syphonEnabled)
                    .toggleStyle(.switch)
                    .disabled(outputManager.isCapturing)

                Toggle("NDI", isOn: $settings.ndiEnabled)
                    .toggleStyle(.switch)
                    .disabled(outputManager.isCapturing)

                Toggle("Audio", isOn: $settings.audioEnabled)
                    .toggleStyle(.switch)
                    .disabled(outputManager.isCapturing)

                Spacer()

                // Start/Stop button
                Button(outputManager.isCapturing ? "Stop" : "Start") {
                    Task {
                        if outputManager.isCapturing {
                            await outputManager.stopCapture()
                        } else {
                            await outputManager.startCapture(settings: settings)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(outputManager.isCapturing ? .red : .green)
            }
            .padding(8)

            // Error display
            if let error = outputManager.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            urlInput = settings.url
        }
    }
}
