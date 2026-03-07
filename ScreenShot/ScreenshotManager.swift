import AppKit
import ScreenCaptureKit

@MainActor
class ScreenshotManager {
    static let shared = ScreenshotManager()

    private var overlayController: OverlayWindowController?

    func startCapture() {
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
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
            } catch {
                print("Screenshot error: \(error)")
            }
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
        var config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width)
        config.height = Int(rect.height)

        // Capture the screenshot
        let screenshot = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return screenshot
    }
}
