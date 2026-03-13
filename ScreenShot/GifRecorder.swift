import AppKit
import ScreenCaptureKit
import ImageIO
import UniformTypeIdentifiers

@MainActor
class GifRecorder: NSObject {
    static let shared = GifRecorder()

    private var recordingWindow: NSWindow?
    private var isRecording = false

    func startRecording(rect: CGRect, settings: AppSettings) {
        isRecording = true
        showRecordingHUD()

        // For now, just show the recording HUD and allow user to stop
        // Full frame capture would require SCStreamOutput delegation
        print("[GIF] Recording started (simplified mode)")
    }

    func stopRecording() async -> URL? {
        isRecording = false
        hideRecordingHUD()

        print("[GIF] Recording stopped")
        // Return nil for now - GIF recording feature requires more complex SCStream setup
        return nil
    }

    private func showRecordingHUD() {
        let frame = NSRect(x: 100, y: 100, width: 200, height: 60)
        let panel = NSPanel(contentRect: frame, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.level = NSWindow.Level.screenSaver
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        panel.isOpaque = false
        panel.hasShadow = false

        let contentView = NSView(frame: frame)
        contentView.wantsLayer = true

        let label = NSTextField(labelWithString: "GIF Recording")
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
            _ = await stopRecording()
        }
    }
}
