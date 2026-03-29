import SwiftUI

@main
struct ScreenShotApp: App {
    @State private var config = AppConfig()

    var body: some Scene {
        MenuBarExtra(content: {
            MenuView(config: config)
        }, label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
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
}
