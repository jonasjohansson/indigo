import SwiftUI
import ScreenCaptureKit

@main
struct IndigoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Redirect stdout/stderr to a log file for debugging
        let logPath = NSHomeDirectory() + "/Documents/indigo.log"
        freopen(logPath, "w", stdout)
        freopen(logPath, "a", stderr)
        print("Indigo started at \(Date())")
    }

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
                // This triggers the permission prompt if not already granted
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            } catch {
                print("Screen recording permission needed: \(error.localizedDescription)")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let outputManager = OutputManager()

    func applicationWillTerminate(_ notification: Notification) {
        // Synchronous cleanup — stop outputs immediately
        outputManager.syphonOutput.stop()
        outputManager.ndiOutput.stop()
    }
}
