import SwiftUI

@main
struct ScreenShotApp: App {
    @State private var config = AppConfig()

    var body: some Scene {
        MenuBarExtra("ScreenShot", systemImage: "camera.viewfinder") {
            MenuView(config: config)
        }

        Settings {
            PreferencesView(config: config)
        }
    }

    init() {
        // Initialize hotkey manager with a slight delay to ensure state is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let appConfig = AppConfig()
            HotkeyManager.shared.start(config: appConfig)
        }
    }
}
