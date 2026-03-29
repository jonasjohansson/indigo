import Foundation
import Combine

final class AppSettings: ObservableObject {
    @Published var url: String {
        didSet { UserDefaults.standard.set(url, forKey: "lastURL") }
    }
    @Published var width: Int {
        didSet { UserDefaults.standard.set(width, forKey: "width") }
    }
    @Published var height: Int {
        didSet { UserDefaults.standard.set(height, forKey: "height") }
    }
    @Published var fps: Int {
        didSet { UserDefaults.standard.set(fps, forKey: "fps") }
    }
    @Published var customCSS: String {
        didSet { UserDefaults.standard.set(customCSS, forKey: "customCSS") }
    }
    @Published var syphonEnabled: Bool {
        didSet { UserDefaults.standard.set(syphonEnabled, forKey: "syphonEnabled") }
    }
    @Published var ndiEnabled: Bool {
        didSet { UserDefaults.standard.set(ndiEnabled, forKey: "ndiEnabled") }
    }
    @Published var audioEnabled: Bool {
        didSet { UserDefaults.standard.set(audioEnabled, forKey: "audioEnabled") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.url = defaults.string(forKey: "lastURL") ?? "https://example.com"
        self.width = defaults.object(forKey: "width") as? Int ?? 1920
        self.height = defaults.object(forKey: "height") as? Int ?? 1080
        self.fps = defaults.object(forKey: "fps") as? Int ?? 60
        self.customCSS = defaults.string(forKey: "customCSS") ?? "body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; }"
        self.syphonEnabled = defaults.object(forKey: "syphonEnabled") as? Bool ?? true
        self.ndiEnabled = defaults.object(forKey: "ndiEnabled") as? Bool ?? true
        self.audioEnabled = defaults.object(forKey: "audioEnabled") as? Bool ?? true
    }
}
