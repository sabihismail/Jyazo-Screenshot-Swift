import SwiftUI
import AppKit

struct MenuView: View {
    var settings: AppSettings
    var config: AppConfig

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
            // The ⌘, shortcut will automatically open Settings
            // Just close the menu
            NSApp.keyWindow?.close()
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
