import AppKit
import SwiftUI
import ScreenCaptureKit
import ApplicationServices

@Observable
final class PermissionsManager {
    static let shared = PermissionsManager()

    var hasScreenRecording: Bool = false
    var hasAccessibility: Bool = false

    private var pollTimer: Timer?
    private var axObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    // Set when AX is granted but we haven't yet prompted for Screen Recording.
    // We wait until the app is foregrounded so the dialog isn't hidden behind System Settings.
    private var pendingScreenRecordingPrompt = false

    var screenRecordingPromptFired: Bool = false
    var allGranted: Bool { hasScreenRecording && hasAccessibility }

    init() {
        refresh()

        axObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.hasAccessibility = AXIsProcessTrusted()
            guard self.hasAccessibility else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let alreadyGranted = await PermissionsManager.checkScreenRecordingViaSCK()
                self.hasScreenRecording = alreadyGranted
                if !alreadyGranted {
                    self.pendingScreenRecordingPrompt = true
                }
            }
        }

        // Fire the Screen Recording prompt once we're back in the foreground
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.pendingScreenRecordingPrompt else { return }
            self.pendingScreenRecordingPrompt = false
            self.screenRecordingPromptFired = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                CGRequestScreenCaptureAccess()
            }
        }
    }

    func refresh() {
        hasAccessibility = AXIsProcessTrusted()
        // CGPreflightScreenCaptureAccess is unreliable — use the real SCK API as truth
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hasScreenRecording = await Self.checkScreenRecordingViaSCK()
        }
    }

    static func checkScreenRecordingViaSCK() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            return false
        }
    }

    func startPolling() {}
    func stopPolling() {}

    func requestMissingPermissions() {
        if !hasAccessibility {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            AXIsProcessTrustedWithOptions(options)
        } else if !hasScreenRecording {
            CGRequestScreenCaptureAccess()
        }
    }

    func openScreenRecordingSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func restart() {
        NSWorkspace.shared.open(Bundle.main.bundleURL)
        NSApp.terminate(nil)
    }
}

// MARK: - Window Manager

final class PermissionsWindowManager {
    static let shared = PermissionsWindowManager()
    private var window: NSWindow?

    func show() {
        if let w = window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 310),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Permissions Required"
        w.contentView = NSHostingView(rootView: PermissionsView())
        w.isReleasedWhenClosed = false
        // Float above other windows so it stays visible while the user works in System Settings
        w.level = .floating
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = w
    }

    func bringToFrontIfVisible() {
        guard let w = window, w.isVisible else { return }
        w.makeKeyAndOrderFront(nil)
    }

    func showIfNeeded() {
        Task { @MainActor in
            let pm = PermissionsManager.shared
            pm.hasAccessibility = AXIsProcessTrusted()
            pm.hasScreenRecording = await PermissionsManager.checkScreenRecordingViaSCK()
            if !pm.allGranted {
                self.show()
            }
        }
    }
}

// MARK: - View

struct PermissionsView: View {
    @State private var permissions = PermissionsManager.shared
    @State private var screenRecordingRequiresRestart = false


    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Jyazo needs two permissions to work.")
                .font(.headline)
                .padding(.bottom, 2)

            PermissionRow(
                title: "Accessibility",
                description: "Attaches the active window title to uploads. No restart needed.",
                granted: permissions.hasAccessibility,
                action: { permissions.openAccessibilitySettings() }
            )

            PermissionRow(
                title: "Screen Recording",
                description: "Required to capture screenshots and GIFs. Restart required after granting.",
                granted: permissions.hasScreenRecording,
                prompted: permissions.screenRecordingPromptFired,
                action: { requestScreenRecording() }
            )

            Divider()

            HStack {
                if permissions.hasAccessibility && permissions.screenRecordingPromptFired && screenRecordingRequiresRestart {
                    Image(systemName: "clock.fill").foregroundColor(.orange)
                    Text("Enabled in Settings — restart to apply.").foregroundColor(.secondary).font(.callout)
                } else if permissions.allGranted && !screenRecordingRequiresRestart {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("All set!").foregroundColor(.secondary).font(.callout)
                } else {
                    Text("Grant the permissions above.")
                        .foregroundColor(.secondary).font(.callout)
                }
                Spacer()
                if screenRecordingRequiresRestart {
                    Button("Restart Jyazo") { permissions.restart() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Done") { NSApp.keyWindow?.close() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear {
            screenRecordingRequiresRestart = !permissions.hasScreenRecording
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                permissions.requestMissingPermissions()
            }
        }
    }

    private func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        permissions.screenRecordingPromptFired = true
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let granted: Bool
    var prompted: Bool = false
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : (prompted ? "clock.fill" : "circle"))
                .foregroundColor(granted ? .green : (prompted ? .orange : .secondary))
                .font(.title3)
                .frame(width: 22)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(description)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !granted && !prompted {
                Button("Grant →") { action() }
                    .buttonStyle(.bordered)
            }
        }
    }
}
