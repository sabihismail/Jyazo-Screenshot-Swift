import AppKit

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
        // Short delay to ensure the overlay window is fully gone before capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let image = CGWindowListCreateImage(
                rect,
                .optionOnScreenOnly,
                kCGNullWindowID,
                .bestResolution
            ) else { return }

            let nsImage = NSImage(cgImage: image, size: NSSize(width: rect.width, height: rect.height))

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([nsImage])
        }
    }
}
