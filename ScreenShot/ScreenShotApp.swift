import SwiftUI
import AppKit

@main
struct ScreenShotApp: App {
    @State private var config = AppConfig()

    var body: some Scene {
        MenuBarExtra(content: {
            MenuView(config: config)
        }, label: {
            menuBarIcon()
        })

        Settings {
            PreferencesView(config: config)
        }
    }

    init() {
        // Request permissions at startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WindowMonitor.shared.requestAllPermissions()
        }

        // Start window monitoring to track active window title
        WindowMonitor.shared.start()
        AppLogger.shared.log("[APP] Window monitoring initialized")

        // Initialize hotkey manager with a slight delay to ensure state is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let appConfig = AppConfig()
            HotkeyManager.shared.start(config: appConfig)
        }
    }

    private func menuBarIcon() -> some View {
        if let nsImage = NSImage(named: "MenuBarIcon") {
            // Resize to menu bar standard size (18pt height)
            let resizedImage = NSImage(size: NSSize(width: 18, height: 18))
            resizedImage.lockFocus()
            nsImage.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18),
                        from: NSRect.zero,
                        operation: .sourceOver,
                        fraction: 1.0)
            resizedImage.unlockFocus()
            resizedImage.isTemplate = true
            return Image(nsImage: resizedImage)
        } else {
            // Fallback to system icon
            return Image(systemName: "camera.fill")
        }
    }
}
