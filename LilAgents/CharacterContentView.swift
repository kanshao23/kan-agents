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

        // Always accept clicks in the pomodoro bar strip (top 8px when timer is active)
        if localPoint.y >= bounds.height - 8 && PomodoroTimer.shared.phase != .idle {
            return self
        }

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
            // Check if click was in the pomodoro bar strip (top 8px when active)
            if dragStart.y >= bounds.height - 8 && PomodoroTimer.shared.phase != .idle {
                PomodoroWindow.toggle()
            } else {
                character?.handleClick()
            }
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        guard let char = character else { return }
        let menu = NSMenu()
        let pt = PomodoroTimer.shared

        // Pomodoro
        let pomTitle: String
        if pt.phase == .idle { pomTitle = "🍅 开始番茄钟" }
        else if pt.isRunning { pomTitle = "⏸ 暂停番茄钟" }
        else { pomTitle = "▶ 继续番茄钟" }
        menu.addItem(menuItem(pomTitle, action: #selector(WalkerCharacter.menuTogglePomodoro), target: char))
        if pt.phase != .idle {
            menu.addItem(menuItem("⏭ 跳过此阶段", action: #selector(WalkerCharacter.menuSkipPomodoro), target: char))
            menu.addItem(menuItem("↺ 重置番茄钟", action: #selector(WalkerCharacter.menuResetPomodoro), target: char))
        }

        // Habits — show undone ones for quick check-in
        let undone = HabitStore.shared.habits.enumerated().filter { !$0.element.isDoneToday }
        if !undone.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem(title: "今日习惯", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for (idx, habit) in undone {
                let item = menuItem("\(habit.emoji) \(habit.name)",
                                    action: #selector(WalkerCharacter.menuCheckInHabit(_:)), target: char)
                item.tag = idx
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(menuItem("💬 打开聊天", action: #selector(WalkerCharacter.menuOpenChat), target: char))

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func menuItem(_ title: String, action: Selector, target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        return item
    }
}
