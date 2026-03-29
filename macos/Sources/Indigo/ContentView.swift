import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var webViewStore = WebViewStore()
    @ObservedObject var outputManager: OutputManager
    @State private var urlInput: String = ""
    @State private var showSettings = false

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

                URLBarView(text: $urlInput) {
                    var trimmed = urlInput.trimmingCharacters(in: .whitespaces)
                    if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
                        trimmed = "https://" + trimmed
                        urlInput = trimmed
                    }
                    settings.url = trimmed
                    webViewStore.loadURL(trimmed)
                }

                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                }
            }
            .padding(8)

            // Settings panel (collapsible)
            if showSettings {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Text("Width")
                            .frame(width: 50, alignment: .trailing)
                        TextField("Width", value: $settings.width, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .disabled(outputManager.isCapturing)

                        Text("Height")
                            .frame(width: 50, alignment: .trailing)
                        TextField("Height", value: $settings.height, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .disabled(outputManager.isCapturing)

                        Button("720p") { settings.width = 1280; settings.height = 720 }
                            .buttonStyle(.bordered)
                            .disabled(outputManager.isCapturing)
                        Button("1080p") { settings.width = 1920; settings.height = 1080 }
                            .buttonStyle(.bordered)
                            .disabled(outputManager.isCapturing)
                        Button("4K") { settings.width = 3840; settings.height = 2160 }
                            .buttonStyle(.bordered)
                            .disabled(outputManager.isCapturing)

                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Text("CSS")
                            .frame(width: 50, alignment: .trailing)
                        TextField("Custom CSS", text: $settings.customCSS)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))

                        Button("Refresh Cache") {
                            webViewStore.refreshCache()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

                Divider()
            }

            // Web view
            WebRendererView(store: webViewStore, url: settings.url)
                .onAppear {
                    outputManager.webViewStore = webViewStore
                }

            Divider()

            // Control strip
            HStack(spacing: 16) {
                Picker("", selection: $settings.fps) {
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }
                .labelsHidden()
                .frame(width: 90)

                Text(String(format: "%dx%d", settings.width, settings.height))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)

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
