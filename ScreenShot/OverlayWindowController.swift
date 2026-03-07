import AppKit

class OverlayWindowController: NSObject {
    private var panel: NSPanel?

    func show(completion: @escaping (CGRect?) -> Void) {
        guard let screen = NSScreen.main else {
            completion(nil)
            return
        }

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false

        let view = SelectionView(frame: screen.frame)
        view.onComplete = { [weak self, weak panel] rect in
            panel?.orderOut(nil)
            self?.panel = nil
            completion(rect)
        }

        panel.contentView = view
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(view)
        self.panel = panel
    }
}

class SelectionView: NSView {
    var onComplete: ((CGRect?) -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero
    private var isDragging = false

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        isDragging = false
        setNeedsDisplay(bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        isDragging = true
        currentRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging, currentRect.width > 5, currentRect.height > 5 else {
            startPoint = nil
            currentRect = .zero
            isDragging = false
            setNeedsDisplay(bounds)
            return
        }
        let cgRect = convertToCGCoordinates(currentRect)
        startPoint = nil
        isDragging = false
        onComplete?(cgRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            startPoint = nil
            currentRect = .zero
            isDragging = false
            onComplete?(nil)
        }
    }

    // Convert NSView local rect → CG screen coordinates (origin top-left)
    private func convertToCGCoordinates(_ rect: NSRect) -> CGRect {
        guard let window = self.window else { return rect }
        let windowRect = convert(rect, to: nil)
        let screenRect = window.convertToScreen(windowRect)
        let screenHeight = NSScreen.main?.frame.height ?? screenRect.maxY
        return CGRect(
            x: screenRect.origin.x,
            y: screenHeight - screenRect.origin.y - screenRect.height,
            width: screenRect.width,
            height: screenRect.height
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let overlay = NSColor.black.withAlphaComponent(0.4).cgColor

        if !isDragging || currentRect.isEmpty {
            ctx.setFillColor(overlay)
            ctx.fill(bounds)
        } else {
            ctx.setFillColor(overlay)
            // Top
            ctx.fill(CGRect(x: 0, y: currentRect.maxY, width: bounds.width, height: bounds.maxY - currentRect.maxY))
            // Bottom
            ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: currentRect.minY))
            // Left
            ctx.fill(CGRect(x: 0, y: currentRect.minY, width: currentRect.minX, height: currentRect.height))
            // Right
            ctx.fill(CGRect(x: currentRect.maxX, y: currentRect.minY, width: bounds.maxX - currentRect.maxX, height: currentRect.height))

            // Selection border
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(1.5)
            ctx.stroke(currentRect.insetBy(dx: 0.75, dy: 0.75))
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
