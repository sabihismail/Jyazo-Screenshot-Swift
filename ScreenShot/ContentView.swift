import SwiftUI
import AppKit
import ScreenCaptureKit

class PreferencesWindowManager {
    static let shared = PreferencesWindowManager()
    private var preferencesWindow: NSWindow?

    func showPreferences(config: AppConfig) {
        // Close existing window if open
        if let window = preferencesWindow, window.isVisible {
            window.close()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.contentView = NSHostingView(rootView: PreferencesView(config: config))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.preferencesWindow = window
    }
}

struct MenuView: View {
    var config: AppConfig

    var body: some View {
        Button("Capture Region") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                ScreenshotManager.shared.startCapture(config: config)
            }
        }
        .keyboardShortcut("4", modifiers: [.command, .shift])

        Button("Record GIF") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task {
                    let manager = OverlayWindowController()
                    manager.show { rect in
                        guard let rect, !rect.isEmpty else { return }
                        GifRecorder.shared.startRecording(rect: rect, config: config)
                    }
                }
            }
        }
        .keyboardShortcut("g", modifiers: [.command, .shift])

        Divider()

        Button("Preferences…") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                PreferencesWindowManager.shared.showPreferences(config: config)
            }
        }
        .keyboardShortcut(",", modifiers: [.command])

        Button("Request Permissions (Screen, Audio, Accessibility)") {
            WindowMonitor.shared.requestAllPermissions()
        }

        Divider()

        // Show log button based on log file count
        if AppLogger.shared.getLogFileCount() <= 1 {
            Button("Open Logs") {
                AppLogger.shared.showLogDirectory()
            }
        } else {
            Button("Open Latest Log") {
                AppLogger.shared.openLogFile()
            }
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
