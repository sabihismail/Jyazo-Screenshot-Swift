import SwiftUI

@main
struct ScreenShotApp: App {
    @State private var settings = AppSettings()
    @State private var config = AppConfig()

    var body: some Scene {
        MenuBarExtra("ScreenShot", systemImage: "camera.viewfinder") {
            MenuView(settings: settings, config: config)
        }
        .onAppear {
            HotkeyManager.shared.start(settings: settings)
        }

        Settings {
            PreferencesView(settings: settings, config: config)
        }
    }
}
