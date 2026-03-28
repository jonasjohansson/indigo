import SwiftUI
import ScreenCaptureKit

@main
struct IndigoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(outputManager: appDelegate.outputManager)
                .onAppear {
                    requestScreenCapturePermission()
                }
        }
    }

    private func requestScreenCapturePermission() {
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            } catch {
                NSLog("Screen recording permission needed: %@", error.localizedDescription)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let outputManager = OutputManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app activates properly when launched from terminal
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        outputManager.syphonOutput.stop()
        outputManager.ndiOutput.stop()
    }
}
