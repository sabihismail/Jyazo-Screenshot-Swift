import SwiftUI

@main
struct ScreenShotApp: App {
    @State private var settings = AppSettings()
    @State private var config = AppConfig()

    var body: some Scene {
        MenuBarExtra("ScreenShot", systemImage: "camera.viewfinder") {
            MenuView(settings: settings, config: config)
        }

        Settings {
            PreferencesView(settings: settings, config: config)
        }
    }

    init() {
        // Initialize hotkey manager with a slight delay to ensure state is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let appSettings = AppSettings()
            HotkeyManager.shared.start(settings: appSettings)
        }
    }
}
