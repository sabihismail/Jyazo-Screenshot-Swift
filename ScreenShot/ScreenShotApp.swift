import SwiftUI

@main
struct ScreenShotApp: App {
    var body: some Scene {
        MenuBarExtra("ScreenShot", systemImage: "camera.viewfinder") {
            MenuView()
        }
    }
}
