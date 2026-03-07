import SwiftUI
import AppKit

struct MenuView: View {
    var body: some View {
        Button("Capture Region") {
            // Delay so the menu dismisses before the overlay appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                ScreenshotManager.shared.startCapture()
            }
        }
        .keyboardShortcut("4", modifiers: [.command, .shift])

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
