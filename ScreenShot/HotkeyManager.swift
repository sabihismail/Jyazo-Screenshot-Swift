import AppKit

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventMonitor: Any?

    func start(config: AppConfig) {
        setupGlobalHotkeys(config: config)
    }

    func update(config: AppConfig) {
        // Restart monitoring with new settings
        stopMonitoring()
        setupGlobalHotkeys(config: config)
    }

    private func setupGlobalHotkeys(config: AppConfig) {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            Task { @MainActor in
                self.handleKeyEvent(event, config: config)
            }
        }
    }

    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent, config: AppConfig) {
        let modifiers = NSEvent.ModifierFlags(rawValue: config.imageShortcutModifiers)
        let gifModifiers = NSEvent.ModifierFlags(rawValue: config.gifShortcutModifiers)

        // Check image shortcut (default: Cmd+Shift+C)
        if config.enableImageShortcut && matchesHotkey(event, key: config.imageShortcutKey, modifiers: modifiers) {
            print("[HOTKEY] Image shortcut triggered")
            ScreenshotManager.shared.startCapture(config: config)
        }

        // Check GIF shortcut (default: Cmd+Shift+G)
        if config.enableGIFShortcut && matchesHotkey(event, key: config.gifShortcutKey, modifiers: gifModifiers) {
            print("[HOTKEY] GIF shortcut triggered")
            Task {
                let manager = OverlayWindowController()
                manager.show { rect in
                    guard let rect, !rect.isEmpty else { return }
                    GifRecorder.shared.startRecording(rect: rect, config: config)
                }
            }
        }
    }

    private func matchesHotkey(_ event: NSEvent, key: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        // Get the character from keyCode
        let eventKey = keyFromKeyCode(event.keyCode)
        return eventKey.lowercased() == key.lowercased() && event.modifierFlags.contains(modifiers)
    }

    private func keyFromKeyCode(_ keyCode: UInt16) -> String {
        // Map keyCode to character
        let keyMapping: [UInt16: String] = [
            6: "z", 7: "x", 8: "c", 9: "v",  // ZXCV
            11: "b", 12: "q", 13: "w", 14: "e",  // BQWE
            15: "r", 16: "y", 17: "t", 18: "1",  // RYRT1
            19: "2", 20: "3", 21: "4", 22: "6",  // 23456
            23: "5", 24: "=", 25: "9", 26: "7",  // =97
            28: "-", 29: "0", 30: "]", 31: "o",  // -0]O
            32: "u", 33: "[", 34: "i", 35: "p",  // U[IP
            36: "\r", 37: "l", 38: "j", 39: "'",  // RLJ'
            40: "k", 41: ";", 42: "\\", 43: ",",  // K;\\,
            44: "/", 45: "n", 46: "m", 47: ".",  // /NM.
            49: " ", 50: "`", 65: ".", 67: "*",  // Space`.*
            69: "+", 70: "?", 78: "-", 81: "=",  // +?-=
            82: "0", 83: "1", 84: "2", 85: "3",  // 0123
            86: "4", 87: "5", 88: "6", 89: "7",  // 4567
            91: "8", 92: "9"  // 89
        ]

        return keyMapping[keyCode] ?? String(format: "%d", keyCode)
    }
}
