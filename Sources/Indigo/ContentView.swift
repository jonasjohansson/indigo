import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var webViewStore = WebViewStore()
    @ObservedObject var outputManager: OutputManager
    @State private var urlInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack(spacing: 8) {
                Button(action: { webViewStore.goBack() }) {
                    Image(systemName: "chevron.left")
                }

                Button(action: { webViewStore.goForward() }) {
                    Image(systemName: "chevron.right")
                }

                Button(action: { webViewStore.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }

                TextField("URL", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        var trimmed = urlInput.trimmingCharacters(in: .whitespaces)
                        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
                            trimmed = "https://" + trimmed
                            urlInput = trimmed
                        }
                        settings.url = trimmed
                    }
            }
            .padding(8)

            // Web view
            WebRendererView(store: webViewStore, url: settings.url)

            Divider()

            // Control strip
            HStack(spacing: 16) {
                Picker("", selection: $settings.resolution) {
                    ForEach(Resolution.presets) { res in
                        Text(res.label).tag(res)
                    }
                }
                .labelsHidden()
                .frame(width: 140)

                Picker("", selection: $settings.fps) {
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }
                .labelsHidden()
                .frame(width: 90)

                Spacer()

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
