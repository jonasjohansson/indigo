import Foundation
import Combine

struct Resolution: Hashable, Identifiable {
    let id: String
    let width: Int
    let height: Int
    var label: String { "\(width)x\(height)" }

    init(width: Int, height: Int) {
        self.id = "\(width)x\(height)"
        self.width = width
        self.height = height
    }

    static let presets: [Resolution] = [
        Resolution(width: 1280, height: 720),
        Resolution(width: 1920, height: 1080),
        Resolution(width: 3840, height: 2160),
    ]

    static func == (lhs: Resolution, rhs: Resolution) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

final class AppSettings: ObservableObject {
    @Published var url: String {
        didSet { UserDefaults.standard.set(url, forKey: "lastURL") }
    }
    @Published var resolution: Resolution {
        didSet { UserDefaults.standard.set(resolution.id, forKey: "resolution") }
    }
    @Published var fps: Int {
        didSet { UserDefaults.standard.set(fps, forKey: "fps") }
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
        self.fps = defaults.object(forKey: "fps") as? Int ?? 60
        self.syphonEnabled = defaults.object(forKey: "syphonEnabled") as? Bool ?? true
        self.ndiEnabled = defaults.object(forKey: "ndiEnabled") as? Bool ?? true
        self.audioEnabled = defaults.object(forKey: "audioEnabled") as? Bool ?? true

        if let resId = defaults.string(forKey: "resolution"),
           let preset = Resolution.presets.first(where: { $0.id == resId }) {
            self.resolution = preset
        } else {
            self.resolution = Resolution.presets[1]
        }
    }
}
