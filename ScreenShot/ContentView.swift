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

        Divider()

        Button("Preferences…") {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: NSApp.delegate, from: nil)
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
