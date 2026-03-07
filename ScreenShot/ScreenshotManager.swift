import AppKit
import ScreenCaptureKit

@MainActor
class ScreenshotManager {
    static let shared = ScreenshotManager()

    private var overlayController: OverlayWindowController?
    private var currentSettings: AppSettings?
    private var currentConfig: AppConfig?

    func startCapture(settings: AppSettings, config: AppConfig) {
        self.currentSettings = settings
        self.currentConfig = config

        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            return
        }

        overlayController = OverlayWindowController()
        overlayController?.show { [weak self] rect in
            guard let rect, !rect.isEmpty else { return }
            self?.captureRegion(rect)
        }
    }

    private func captureRegion(_ rect: CGRect) {
        Task {
            do {
                let image = try await captureScreenRegion(rect)

                // Save to disk if enabled
                var savedURL: URL?
                if let settings = currentSettings, settings.saveAllImages {
                    savedURL = saveToDisk(image: image, directory: settings.saveDirectory)
                }

                // Copy to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])

                // Upload to server
                if let settings = currentSettings, let config = currentConfig {
                    if let url = savedURL {
                        _ = try await UploadManager.shared.upload(imageURL: url, settings: settings, config: config)
                    } else {
                        // If not saved to disk, save to temp and upload
                        let tempURL = saveToDisk(image: image, directory: NSTemporaryDirectory())
                        if let tempURL = tempURL {
                            _ = try await UploadManager.shared.upload(imageURL: tempURL, settings: settings, config: config)
                            try? FileManager.default.removeItem(at: tempURL)
                        }
                    }
                }
            } catch {
                print("Screenshot error: \(error)")
            }
        }
    }

    private func saveToDisk(image: NSImage, directory: String) -> URL? {
        let fileManager = FileManager.default
        let fileName = "Screenshot_\(ISO8601DateFormatter().string(from: Date())).png"
        let filePath = (directory as NSString).appendingPathComponent(fileName)

        do {
            try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)

            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return nil
            }

            try pngData.write(to: URL(fileURLWithPath: filePath), options: .atomic)
            print("[CAPTURE] Saved to: \(filePath)")
            return URL(fileURLWithPath: filePath)
        } catch {
            print("[CAPTURE] Failed to save: \(error)")
            return nil
        }
    }

    private func captureScreenRegion(_ rect: CGRect) async throws -> NSImage {
        // Get available content (displays, windows)
        let availableContent = try await SCShareableContent.current

        // Find the display containing the rect
        guard let display = availableContent.displays.first(where: { screen in
            screen.frame.contains(CGPoint(x: rect.midX, y: rect.midY))
        }) ?? availableContent.displays.first else {
            throw NSError(domain: "ScreenCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        // Create filter for the entire display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure the stream to capture only the requested region
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width)
        config.height = Int(rect.height)

        // Capture the screenshot
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: cgImage, size: NSZeroSize)
    }
}
