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
            showingPreferences = true
        }
        .keyboardShortcut(",", modifiers: [.command])
        .sheet(isPresented: $showingPreferences) {
            PreferencesView(settings: settings, config: config)
                .frame(minWidth: 500, minHeight: 400)
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
