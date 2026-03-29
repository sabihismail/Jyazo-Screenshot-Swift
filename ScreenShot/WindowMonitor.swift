import AppKit
import ApplicationServices
import ScreenCaptureKit

class WindowMonitor {
    static let shared = WindowMonitor()

    private var currentWindowTitle: String = ""
    private var lastLoggedTitle: String = ""
    private let queue = DispatchQueue(label: "com.arkaprime.windowmonitor")
    private var timer: DispatchSourceTimer?
    private var appActivationObserver: NSObjectProtocol?

    func getCurrentWindowTitle() -> String {
        return currentWindowTitle
    }

    func requestAllPermissions() {
        AppLogger.shared.log("[WINDOW] === Requesting All Permissions ===")

        // Request Accessibility
        AppLogger.shared.log("[WINDOW] Requesting Accessibility permission...")
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let axTrusted = AXIsProcessTrustedWithOptions(options)
        AppLogger.shared.log("[WINDOW] Accessibility: \(axTrusted ? "✓ Granted" : "✗ Denied")")

        // Screen Recording and System Audio Recording prompts will appear when:
        // - User clicks "Capture Region" (triggers Screen Recording permission)
        // - User clicks "Record GIF" (triggers System Audio Recording permission)
        AppLogger.shared.log("[WINDOW] Screen Recording: will prompt on first screenshot")
        AppLogger.shared.log("[WINDOW] System Audio Recording: will prompt on first GIF record")

        if axTrusted {
            // Restart monitoring since we now have Accessibility permission
            AppLogger.shared.log("[WINDOW] Restarting window monitoring...")
            start()
        }

        AppLogger.shared.log("[WINDOW] === Permission requests complete ===")
    }

    func start() {
        queue.async { [weak self] in
            self?.setupWindowMonitoring()
        }
    }

    private func setupWindowMonitoring() {
        AppLogger.shared.log("[WINDOW] Setting up window monitoring...")

        // Check if we have accessibility access
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        AppLogger.shared.log("[WINDOW] Accessibility permission check: \(isTrusted ? "✓ Granted" : "✗ Denied")")

        guard isTrusted else {
            AppLogger.shared.log("[WINDOW] ✗ Accessibility permission denied - cannot track window titles")
            return
        }

        AppLogger.shared.log("[WINDOW] ✓ Accessibility permission granted")

        // Get the frontmost application
        AppLogger.shared.log("[WINDOW] Getting initial window title...")
        updateActiveWindowTitle()

        // Listen for app activation (instant detection for app switches)
        AppLogger.shared.log("[WINDOW] Setting up app activation notifications...")
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                let appName = app.localizedName ?? "Unknown"
                AppLogger.shared.log("[WINDOW] [NOTIFY] App activated: \(appName)")

                // Skip if ScreenShot app itself became active (don't override window title during capture)
                if app.bundleIdentifier == "arkaprime.Jyazo" {
                    AppLogger.shared.log("[WINDOW] [NOTIFY] → Skipping (ScreenShot app, preserving capture title)")
                    return
                }
                AppLogger.shared.log("[WINDOW] [NOTIFY] → Polling immediately")
                self?.queue.async { [weak self] in
                    self?.updateActiveWindowTitle()
                }
            }
        }
        self.appActivationObserver = observer

        // Use DispatchSourceTimer on the dispatch queue (has proper run loop)
        // Increased to 2s interval since app switches are now caught by notifications
        AppLogger.shared.log("[WINDOW] Starting timer-based monitoring (2s fallback interval for within-app changes)...")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        self.timer = timer
        timer.schedule(deadline: .now(), repeating: .milliseconds(2000))
        timer.setEventHandler { [weak self] in
            self?.updateActiveWindowTitle()
        }
        timer.resume()

        AppLogger.shared.log("[WINDOW] ✓ Window monitoring started successfully")
    }

    private func updateActiveWindowTitle() {
        AppLogger.shared.log("[WINDOW] [POLL] Timer fired - checking active window...")

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            AppLogger.shared.log("[WINDOW] [POLL] ✗ No frontmost app found")
            currentWindowTitle = ""
            return
        }

        let appName = frontmostApp.localizedName ?? "Unknown"
        let pid = frontmostApp.processIdentifier

        // Skip updating title if Jyazo itself is active (preserve capture title during screenshot)
        if frontmostApp.bundleIdentifier == "arkaprime.Jyazo" {
            AppLogger.shared.log("[WINDOW] [POLL] Jyazo app active - skipping title update to preserve capture title")
            return
        }

        AppLogger.shared.log("[WINDOW] [POLL] Frontmost app: \(appName) (PID: \(pid))")

        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        AppLogger.shared.log("[WINDOW] [POLL] AX window query result: \(result == .success ? "✓ Success" : "✗ Failed (\(result))")")

        if result == .success, focusedWindow != nil {
            let window = focusedWindow as! AXUIElement
            var title: AnyObject?
            let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)

            if titleResult == .success, let titleStr = title as? String, !titleStr.isEmpty {
                AppLogger.shared.log("[WINDOW] [POLL] Window title retrieved: \(titleStr)")
                currentWindowTitle = titleStr
            } else {
                // Fallback to app name if window title unavailable
                AppLogger.shared.log("[WINDOW] [POLL] Window title unavailable (result: \(titleResult)), using app name: \(appName)")
                currentWindowTitle = appName
            }
        } else {
            // Fallback to app name
            AppLogger.shared.log("[WINDOW] [POLL] No focused window, using app name: \(appName)")
            currentWindowTitle = appName
        }

        // Log only when window title changes
        if currentWindowTitle != lastLoggedTitle {
            AppLogger.shared.log("[WINDOW] [CHANGE] Title changed: '\(lastLoggedTitle)' → '\(currentWindowTitle)'")
            lastLoggedTitle = currentWindowTitle
            AppLogger.shared.log("[WINDOW] Active: \(currentWindowTitle.isEmpty ? "(empty)" : currentWindowTitle)")
        } else {
            AppLogger.shared.log("[WINDOW] [POLL] Title unchanged: '\(currentWindowTitle)'")
        }
    }

    func stop() {
        // Remove app activation observer
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.appActivationObserver = nil
        }

        // Cancel polling timer
        if let timer = timer {
            timer.cancel()
            self.timer = nil
            AppLogger.shared.log("[WINDOW] Window monitoring stopped")
        }
    }

    deinit {
        stop()
    }
}
