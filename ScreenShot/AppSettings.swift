import Foundation
import Observation
import AppKit

@Observable
final class AppSettings {
    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    var enableImageShortcut: Bool {
        didSet { UserDefaults.standard.set(enableImageShortcut, forKey: "enableImageShortcut") }
    }

    var imageShortcutKey: String {
        didSet { UserDefaults.standard.set(imageShortcutKey, forKey: "imageShortcutKey") }
    }

    var imageShortcutModifiers: NSEvent.ModifierFlags {
        didSet { UserDefaults.standard.set(imageShortcutModifiers.rawValue, forKey: "imageShortcutModifiers") }
    }

    var enableGIFShortcut: Bool {
        didSet { UserDefaults.standard.set(enableGIFShortcut, forKey: "enableGIFShortcut") }
    }

    var gifShortcutKey: String {
        didSet { UserDefaults.standard.set(gifShortcutKey, forKey: "gifShortcutKey") }
    }

    var gifShortcutModifiers: NSEvent.ModifierFlags {
        didSet { UserDefaults.standard.set(gifShortcutModifiers.rawValue, forKey: "gifShortcutModifiers") }
    }

    var saveAllImages: Bool {
        didSet { UserDefaults.standard.set(saveAllImages, forKey: "saveAllImages") }
    }

    var saveDirectory: String {
        didSet { UserDefaults.standard.set(saveDirectory, forKey: "saveDirectory") }
    }

    var enableSound: Bool {
        didSet { UserDefaults.standard.set(enableSound, forKey: "enableSound") }
    }

    var gifFrameRate: Int {
        didSet { UserDefaults.standard.set(gifFrameRate, forKey: "gifFrameRate") }
    }

    init() {
        let defaults = UserDefaults.standard

        self.serverURL = defaults.string(forKey: "serverURL") ?? ""
        self.enableImageShortcut = defaults.bool(forKey: "enableImageShortcut")
        self.imageShortcutKey = defaults.string(forKey: "imageShortcutKey") ?? "c"
        self.imageShortcutModifiers = NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: "imageShortcutModifiers")))
        self.enableGIFShortcut = defaults.bool(forKey: "enableGIFShortcut")
        self.gifShortcutKey = defaults.string(forKey: "gifShortcutKey") ?? "g"
        self.gifShortcutModifiers = NSEvent.ModifierFlags(rawValue: UInt(defaults.integer(forKey: "gifShortcutModifiers")))
        self.saveAllImages = defaults.bool(forKey: "saveAllImages")
        self.saveDirectory = defaults.string(forKey: "saveDirectory") ?? Self.defaultSaveDirectory()
        self.enableSound = defaults.bool(forKey: "enableSound")
        self.gifFrameRate = defaults.integer(forKey: "gifFrameRate") > 0 ? defaults.integer(forKey: "gifFrameRate") : 10
    }

    static func defaultSaveDirectory() -> String {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        return picturesURL.appendingPathComponent("Jyazo").path
    }
}
