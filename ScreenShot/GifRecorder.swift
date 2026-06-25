import AppKit
import ScreenCaptureKit
import ImageIO
import UniformTypeIdentifiers
import CoreMedia

@MainActor
class GifRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    static let shared = GifRecorder()

    private var stream: SCStream?
    private var frames: [CGImage] = []
    private var recordingRect: CGRect = .zero
    private(set) var isRecording = false
    private(set) var isPaused = false
    private var currentConfig: AppConfig?

    private var borderPanel: NSPanel?
    private var controlsPanel: NSPanel?

    // MARK: - Public API

    func startRecording(rect: CGRect, config: AppConfig) {
        guard !isRecording else { return }
        recordingRect = rect
        currentConfig = config
        frames.removeAll()
        isRecording = true
        isPaused = false

        showRecordingOverlay(rect: rect)

        Task {
            do {
                try await setupAndStartStream(rect: rect)
            } catch {
                AppLogger.shared.log("[GIF] Failed to start recording: \(error)")
                isRecording = false
                hideRecordingOverlay()
            }
        }
    }

    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        AppLogger.shared.log("[GIF] Paused (\(frames.count) frames)")
        (controlsPanel?.contentView as? RecordingControlsView)?.setIsPaused(true)
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }
        isPaused = false
        AppLogger.shared.log("[GIF] Resumed")
        (controlsPanel?.contentView as? RecordingControlsView)?.setIsPaused(false)
    }

    func cancelRecording() {
        guard isRecording else { return }
        isRecording = false
        isPaused = false
        hideRecordingOverlay()
        Task {
            await stopStream()
            frames.removeAll()
            AppLogger.shared.log("[GIF] Cancelled")
        }
    }

    func finishRecording() {
        guard isRecording else { return }
        isRecording = false
        isPaused = false
        hideRecordingOverlay()

        let capturedFrames = frames
        frames.removeAll()
        let config = currentConfig

        Task {
            await stopStream()
            guard !capturedFrames.isEmpty else {
                AppLogger.shared.log("[GIF] No frames captured")
                return
            }
            AppLogger.shared.log("[GIF] Encoding \(capturedFrames.count) frames...")
            let gifURL = await Task.detached(priority: .userInitiated) {
                GifRecorder.encodeGif(frames: capturedFrames)
            }.value
            guard let gifURL else {
                AppLogger.shared.log("[GIF] Encoding failed")
                return
            }
            AppLogger.shared.log("[GIF] ✓ Encoded: \(gifURL.lastPathComponent)")
            if let config {
                do {
                    let resultURL = try await UploadManager.shared.upload(imageURL: gifURL, config: config)
                    if !resultURL.isEmpty, let url = URL(string: resultURL) {
                        await MainActor.run { NSWorkspace.shared.open(url) }
                    }
                } catch {
                    AppLogger.shared.log("[GIF] Upload failed: \(error)")
                }
            }
            try? FileManager.default.removeItem(at: gifURL)
        }
    }

    // MARK: - Stream

    private func stopStream() async {
        guard let stream else { return }
        do { try await stream.stopCapture() } catch { }
        self.stream = nil
    }

    private func setupAndStartStream(rect: CGRect) async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) })
                ?? content.displays.first else {
            throw NSError(domain: "GIF", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        // Exclude our overlay panels so the border and controls never appear in captured frames
        let overlayIDs = Set([borderPanel?.windowNumber, controlsPanel?.windowNumber]
            .compactMap { $0 }.map { CGWindowID($0) })
        let excludedWindows = content.windows.filter { overlayIDs.contains($0.windowID) }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        let cfg = SCStreamConfiguration()
        cfg.sourceRect = rect
        cfg.width = Int(rect.width)
        cfg.height = Int(rect.height)
        cfg.captureResolution = .automatic
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 10) // 10 fps

        let newStream = SCStream(filter: filter, configuration: cfg, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        try await newStream.startCapture()
        self.stream = newStream
        AppLogger.shared.log("[GIF] Stream started at 10 fps")
    }

    // MARK: - Encoding

    nonisolated static func encodeGif(frames: [CGImage]) -> URL? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("recording_\(UUID().uuidString).gif")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
            return nil
        }
        let frameProps: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: 0.1]
        ]
        for frame in frames {
            CGImageDestinationAddImage(dest, frame, frameProps as CFDictionary)
        }
        CGImageDestinationSetProperties(dest, [
            kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]
        ] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return url
    }

    // MARK: - Overlay

    private func showRecordingOverlay(rect: CGRect) {
        guard let screen = NSScreen.main else { return }

        // CG coordinates (top-left origin) → NS screen coordinates (bottom-left origin)
        let nsRect = NSRect(
            x: rect.origin.x,
            y: screen.frame.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        // Full-screen border panel — ignores mouse so the user can still interact with recorded content
        let bp = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        bp.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        bp.backgroundColor = .clear
        bp.isOpaque = false
        bp.hasShadow = false
        bp.ignoresMouseEvents = true
        bp.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // View-local rect: the panel covers the whole screen, so subtract screen origin
        let viewRect = NSRect(
            x: nsRect.minX - screen.frame.minX,
            y: nsRect.minY - screen.frame.minY,
            width: nsRect.width,
            height: nsRect.height
        )
        bp.contentView = RecordingBorderView(frame: screen.frame, recordingRect: viewRect)
        bp.orderFront(nil)
        borderPanel = bp

        // Controls panel — positioned below the recording rect (or above if near bottom)
        let cw: CGFloat = 224, ch: CGFloat = 46
        let cx = nsRect.midX - cw / 2
        let cy = nsRect.minY > ch + 16 ? nsRect.minY - ch - 8 : nsRect.maxY + 8
        let cp = NSPanel(
            contentRect: NSRect(x: cx, y: cy, width: cw, height: ch),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        cp.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        cp.backgroundColor = .clear
        cp.isOpaque = false
        cp.hasShadow = true
        cp.ignoresMouseEvents = false
        cp.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let cv = RecordingControlsView(frame: NSRect(origin: .zero, size: NSSize(width: cw, height: ch)))
        cv.onPause = { [weak self] in self?.pauseRecording() }
        cv.onResume = { [weak self] in self?.resumeRecording() }
        cv.onCancel = { [weak self] in self?.cancelRecording() }
        cv.onDone = { [weak self] in self?.finishRecording() }
        cp.contentView = cv
        cp.orderFront(nil)
        controlsPanel = cp
    }

    private func hideRecordingOverlay() {
        borderPanel?.orderOut(nil)
        borderPanel = nil
        controlsPanel?.orderOut(nil)
        controlsPanel = nil
    }
}

// MARK: - SCStream callbacks

extension GifRecorder {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard isRecording, !isPaused, outputType == .screen else { return }
        if let image = sampleBuffer.cgImage {
            frames.append(image)
        }
    }
}

// MARK: - CMSampleBuffer → CGImage

extension CMSampleBuffer {
    var cgImage: CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else { return nil }
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        return CIContext().createCGImage(ciImage, from: ciImage.extent)
    }
}

// MARK: - Animated recording border

class RecordingBorderView: NSView {
    private let recordingRect: NSRect
    private var dashPhase: CGFloat = 0
    private var animTimer: Timer?

    init(frame: NSRect, recordingRect: NSRect) {
        self.recordingRect = recordingRect
        super.init(frame: frame)
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.dashPhase -= 2
            self?.needsDisplay = true
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { animTimer?.invalidate() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, !recordingRect.isEmpty else { return }
        ctx.setLineDash(phase: dashPhase, lengths: [8, 4])
        ctx.setStrokeColor(NSColor.red.withAlphaComponent(0.9).cgColor)
        ctx.setLineWidth(2.5)
        ctx.stroke(recordingRect.insetBy(dx: 1.25, dy: 1.25))
    }
}

// MARK: - Controls HUD

class RecordingControlsView: NSView {
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDone: (() -> Void)?

    private let pauseBtn = NSButton()
    private var paused = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupView()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.88).cgColor
        layer?.cornerRadius = frame.height / 2
        layer?.masksToBounds = true

        // Pause / resume
        pauseBtn.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause")
        pauseBtn.isBordered = false
        pauseBtn.contentTintColor = .white
        pauseBtn.target = self
        pauseBtn.action = #selector(pauseTapped)

        // Cancel (xmark)
        let cancelBtn = NSButton()
        cancelBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Cancel")
        cancelBtn.isBordered = false
        cancelBtn.contentTintColor = NSColor(white: 0.55, alpha: 1)
        cancelBtn.target = self
        cancelBtn.action = #selector(cancelTapped)

        // Done
        let doneBtn = NSButton(title: "Done", target: self, action: #selector(doneTapped))
        doneBtn.isBordered = false
        doneBtn.wantsLayer = true
        doneBtn.layer?.backgroundColor = NSColor.systemBlue.cgColor
        doneBtn.layer?.cornerRadius = 6
        doneBtn.contentTintColor = .white
        doneBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        let btnSz: CGFloat = 26
        let doneW: CGFloat = 58
        let gap: CGFloat = 12
        let totalW = btnSz + gap + btnSz + gap + doneW
        let x0 = (frame.width - totalW) / 2
        let midY = frame.height / 2

        pauseBtn.frame = NSRect(x: x0, y: midY - btnSz / 2, width: btnSz, height: btnSz)
        cancelBtn.frame = NSRect(x: x0 + btnSz + gap, y: midY - btnSz / 2, width: btnSz, height: btnSz)
        doneBtn.frame = NSRect(x: x0 + 2 * (btnSz + gap), y: midY - 13, width: doneW, height: 26)

        addSubview(pauseBtn)
        addSubview(cancelBtn)
        addSubview(doneBtn)
    }

    func setIsPaused(_ isPaused: Bool) {
        paused = isPaused
        pauseBtn.image = NSImage(systemSymbolName: isPaused ? "play.fill" : "pause.fill", accessibilityDescription: nil)
    }

    @objc private func pauseTapped() { paused ? onResume?() : onPause?() }
    @objc private func cancelTapped() { onCancel?() }
    @objc private func doneTapped() { onDone?() }
}
