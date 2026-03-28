import AppKit

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class CharacterContentView: NSView {
    weak var character: WalkerCharacter?

    private var dragStart: NSPoint = .zero
    private var windowOriginAtDragStart: NSPoint = .zero
    private var isDragging = false
    private var lastVelocity: NSPoint = .zero
    private var lastDragTime: TimeInterval = 0
    private var lastDragPos: NSPoint = .zero
    private static let dragThreshold: CGFloat = 5

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        else { return false }
        character?.handleFileDrop(urls: urls)
        return true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        guard bounds.contains(localPoint) else { return nil }

        // AVPlayerLayer is GPU-rendered so layer.render(in:) won't capture video pixels.
        // Use CGWindowListCreateImage to sample actual on-screen alpha at click point.
        let screenPoint = window?.convertPoint(toScreen: convert(localPoint, to: nil)) ?? .zero
        // Use the full virtual display height for the CG coordinate flip, not just
        // the main screen. NSScreen coordinates have origin at bottom-left of the
        // primary display, while CG uses top-left. The primary screen's height is
        // the correct basis for the flip across all monitors.
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let flippedY = primaryScreen.frame.height - screenPoint.y

        let captureRect = CGRect(x: screenPoint.x - 0.5, y: flippedY - 0.5, width: 1, height: 1)
        guard let windowID = window?.windowNumber, windowID > 0 else { return nil }

        if let image = CGWindowListCreateImage(
            captureRect,
            .optionIncludingWindow,
            CGWindowID(windowID),
            [.boundsIgnoreFraming, .bestResolution]
        ) {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var pixel: [UInt8] = [0, 0, 0, 0]
            if let ctx = CGContext(
                data: &pixel, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                if pixel[3] > 30 {
                    return self
                }
                return nil
            }
        }

        // Fallback: accept click if within center 60% of the view
        let insetX = bounds.width * 0.2
        let insetY = bounds.height * 0.15
        let hitRect = bounds.insetBy(dx: insetX, dy: insetY)
        return hitRect.contains(localPoint) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        windowOriginAtDragStart = window?.frame.origin ?? .zero
        isDragging = false
        lastVelocity = .zero
        lastDragTime = event.timestamp
        lastDragPos = dragStart
    }

    override func mouseDragged(with event: NSEvent) {
        let pos = convert(event.locationInWindow, from: nil)
        let dx = pos.x - dragStart.x
        let dy = pos.y - dragStart.y
        if !isDragging && sqrt(dx*dx + dy*dy) < Self.dragThreshold { return }
        if !isDragging {
            isDragging = true
            character?.isBeingDragged = true
        }
        let newOrigin = NSPoint(
            x: windowOriginAtDragStart.x + dx,
            y: windowOriginAtDragStart.y + dy
        )
        window?.setFrameOrigin(newOrigin)

        let now = event.timestamp
        let dt = now - lastDragTime
        if dt > 0 {
            let curPos = convert(event.locationInWindow, from: nil)
            lastVelocity = NSPoint(
                x: (curPos.x - lastDragPos.x) / CGFloat(dt),
                y: (curPos.y - lastDragPos.y) / CGFloat(dt)
            )
            lastDragTime = now
            lastDragPos = curPos
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            character?.endDrag(velocity: lastVelocity)
        } else {
            character?.handleClick()
        }
    }
}
