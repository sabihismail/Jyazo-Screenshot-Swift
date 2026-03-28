import AppKit
import ScreenCaptureKit

@MainActor
class ScreenshotManager {
    static let shared = ScreenshotManager()

    private var overlayController: OverlayWindowController?
    private var currentConfig: AppConfig?

    func startCapture(config: AppConfig) {
        self.currentConfig = config

        // Don't explicitly request permissions - let ScreenCaptureKit handle it when needed
        // This way the permission prompt only appears once when actually capturing

        // Show overlay - ScreenCaptureKit will request permission during actual capture
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
                if let config = currentConfig, config.saveAllImages {
                    savedURL = saveToDisk(image: image, directory: config.saveDirectory)
                }

                // Copy to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])

                // Upload to server
                if let config = currentConfig {
                    let uploadURL: URL?
                    if let url = savedURL {
                        uploadURL = try await UploadManager.shared.upload(imageURL: url, config: config).isEmpty ? nil : URL(string: try await UploadManager.shared.upload(imageURL: url, config: config))
                    } else {
                        // If not saved to disk, save to temp and upload
                        let tempURL = saveToDisk(image: image, directory: NSTemporaryDirectory())
                        if let tempURL = tempURL {
                            let resultURL = try await UploadManager.shared.upload(imageURL: tempURL, config: config)
                            uploadURL = resultURL.isEmpty ? nil : URL(string: resultURL)
                            try? FileManager.default.removeItem(at: tempURL)
                        } else {
                            uploadURL = nil
                        }
                    }

                    // Open the result URL in default browser
                    if let uploadURL = uploadURL {
                        AppLogger.shared.log("[CAPTURE] Opening URL in browser: \(uploadURL.absoluteString)")
                        NSWorkspace.shared.open(uploadURL)
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
            AppLogger.shared.log("[CAPTURE] Saved to: \(filePath)")

            return URL(fileURLWithPath: filePath)
        } catch {
            AppLogger.shared.log("[CAPTURE] Failed to save: \(error)")
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
