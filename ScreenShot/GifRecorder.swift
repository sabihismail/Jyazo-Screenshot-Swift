import AppKit
import ScreenCaptureKit
import ImageIO

@MainActor
class GifRecorder: NSObject {
    static let shared = GifRecorder()

    private var stream: SCStream?
    private var frames: [CGImage] = []
    private var recordingRect: CGRect = .zero
    private var isRecording = false
    private var recordingWindow: NSWindow?

    func startRecording(rect: CGRect, settings: AppSettings) {
        recordingRect = rect
        frames.removeAll()
        isRecording = true

        // Show recording HUD
        showRecordingHUD()

        Task {
            do {
                try await setupAndStartStream(rect: rect)
            } catch {
                print("[GIF] Failed to start recording: \(error)")
                isRecording = false
                hideRecordingHUD()
            }
        }
    }

    func stopRecording() async -> URL? {
        isRecording = false
        hideRecordingHUD()

        if let stream = stream {
            try? await stream.stop()
            self.stream = nil
        }

        guard !frames.isEmpty else {
            print("[GIF] No frames captured")
            return nil
        }

        print("[GIF] Encoding \(frames.count) frames to GIF")
        return encodeGif(frames: frames)
    }

    private func setupAndStartStream(rect: CGRect) async throws {
        let availableContent = try await SCShareableContent.current

        guard let display = availableContent.displays.first(where: { screen in
            screen.frame.contains(CGPoint(x: rect.midX, y: rect.midY))
        }) ?? availableContent.displays.first else {
            throw NSError(domain: "GIF", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        var config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width)
        config.height = Int(rect.height)
        config.captureResolution = .automatic

        let stream = SCStream(filter: filter, configuration: config)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())

        try await stream.start()
        self.stream = stream
        print("[GIF] Recording started")
    }

    private func encodeGif(frames: [CGImage]) -> URL? {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recording_\(UUID().uuidString).gif")

        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, kUTTypeGIF, frames.count, nil) else {
            print("[GIF] Failed to create image destination")
            return nil
        }

        let frameDelay: CGFloat = 0.1 // 100ms per frame (10 fps)

        for (index, frame) in frames.enumerated() {
            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: frameDelay
                ]
            ]

            CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)

            if index % 10 == 0 {
                print("[GIF] Encoded frame \(index + 1)/\(frames.count)")
            }
        }

        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0 // Infinite loop
            ]
        ]

        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            print("[GIF] Failed to finalize GIF")
            return nil
        }

        print("[GIF] ✓ GIF created: \(tempURL.path)")
        return tempURL
    }

    private func showRecordingHUD() {
        let panel = NSPanel(contentRect: NSRect(x: 100, y: 100, width: 200, height: 60), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.level = NSWindow.Level.screenSaver
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        panel.isOpaque = false
        panel.hasShadow = false

        let contentView = NSView(frame: panel.contentRect)
        contentView.wantsLayer = true

        let label = NSTextField(labelWithString: "Recording GIF…")
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 14)
        label.frame = NSRect(x: 10, y: 35, width: 180, height: 20)
        contentView.addSubview(label)

        let stopButton = NSButton(frame: NSRect(x: 10, y: 5, width: 180, height: 25))
        stopButton.title = "Stop"
        stopButton.target = self
        stopButton.action = #selector(stopButtonClicked)
        contentView.addSubview(stopButton)

        panel.contentView = contentView
        panel.makeKeyAndOrderFront(nil)
        recordingWindow = panel
    }

    private func hideRecordingHUD() {
        recordingWindow?.orderOut(nil)
        recordingWindow = nil
    }

    @objc private func stopButtonClicked() {
        Task {
            if let gifURL = await stopRecording() {
                // Upload the GIF
                let settings = AppSettings()
                let config = AppConfig()
                try? await UploadManager.shared.upload(imageURL: gifURL, settings: settings, config: config)

                // Clean up temp file
                try? FileManager.default.removeItem(at: gifURL)
            }
        }
    }
}

extension GifRecorder: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isRecording else { return }

        if let image = sampleBuffer.cgImage {
            frames.append(image)
        }
    }
}

// Helper to extract CGImage from CMSampleBuffer
extension CMSampleBuffer {
    var cgImage: CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else { return nil }
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
