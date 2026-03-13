import SwiftUI
import AppKit

struct MenuView: View {
    var settings: AppSettings
    var config: AppConfig
    @State private var showingPreferences = false

    var body: some View {
        Button("Capture Region") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                ScreenshotManager.shared.startCapture(settings: settings, config: config)
            }
        }
        .keyboardShortcut("4", modifiers: [.command, .shift])

        Button("Record GIF") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                Task {
                    let manager = OverlayWindowController()
                    manager.show { rect in
                        guard let rect, !rect.isEmpty else { return }
                        GifRecorder.shared.startRecording(rect: rect, settings: settings)
                    }
                }
            }
        }
        .keyboardShortcut("g", modifiers: [.command, .shift])

        Divider()

        Button("Preferences…") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                openPreferencesWindow(settings: settings, config: config)
            }
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func openPreferencesWindow(settings: AppSettings, config: AppConfig) {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.contentView = NSHostingView(rootView: PreferencesView(settings: settings, config: config))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
