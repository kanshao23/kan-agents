import AppKit

class PomodoroWindow: NSWindow {
    static var shared: PomodoroWindow?

    static func toggle() {
        if let win = shared, win.isVisible {
            win.orderOut(nil)
            return
        }
        if shared == nil {
            shared = PomodoroWindow()
        }
        shared?.orderFrontRegardless()
        shared?.updateUI()
    }

    private let phaseLabel = NSTextField(labelWithString: "🍅  Ready")
    private let timeLabel = NSTextField(labelWithString: "25:00")
    private let sessionDots = NSTextField(labelWithString: "")
    private let startBtn = NSButton()
    private let resetBtn = NSButton()
    private let skipBtn = NSButton()

    init() {
        let W: CGFloat = 260
        let H: CGFloat = 130
        // Position top-right of main screen
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let x = screen.visibleFrame.maxX - W - 20
        let y = screen.visibleFrame.maxY - H - 20
        super.init(contentRect: NSRect(x: x, y: y, width: W, height: H),
                   styleMask: [.borderless, .resizable],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 15)
        collectionBehavior = [.moveToActiveSpace, .stationary]
        isMovableByWindowBackground = true

        setupUI(width: W, height: H)
        updateUI()
    }

    private func setupUI(width W: CGFloat, height H: CGFloat) {
        let card = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 0.97).cgColor
        card.layer?.cornerRadius = 18
        card.layer?.borderWidth = 2
        card.layer?.borderColor = NSColor(red: 0.9, green: 0.35, blue: 0.25, alpha: 0.6).cgColor

        // Phase label
        phaseLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        phaseLabel.textColor = NSColor(red: 0.7, green: 0.25, blue: 0.15, alpha: 1)
        phaseLabel.frame = NSRect(x: 14, y: H - 28, width: W - 80, height: 20)
        card.addSubview(phaseLabel)

        // Session dots
        sessionDots.font = NSFont.systemFont(ofSize: 11)
        sessionDots.textColor = NSColor(red: 0.9, green: 0.35, blue: 0.25, alpha: 0.8)
        sessionDots.alignment = .right
        sessionDots.frame = NSRect(x: W - 80, y: H - 28, width: 66, height: 20)
        card.addSubview(sessionDots)

        // Big time display
        timeLabel.font = NSFont.monospacedSystemFont(ofSize: 34, weight: .bold)
        timeLabel.textColor = NSColor(red: 0.15, green: 0.12, blue: 0.1, alpha: 1)
        timeLabel.alignment = .center
        timeLabel.frame = NSRect(x: 0, y: H - 72, width: W, height: 44)
        card.addSubview(timeLabel)

        // Buttons
        let tomato = NSColor(red: 0.9, green: 0.35, blue: 0.25, alpha: 1)

        func makeBtn(_ title: String, filled: Bool) -> NSButton {
            let b = NSButton(title: title, target: nil, action: nil)
            b.isBordered = false
            b.wantsLayer = true
            b.layer?.cornerRadius = 10
            if filled {
                b.layer?.backgroundColor = tomato.cgColor
                b.attributedTitle = NSAttributedString(string: title, attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: NSColor.white
                ])
            } else {
                b.layer?.backgroundColor = tomato.withAlphaComponent(0.1).cgColor
                b.layer?.borderWidth = 1
                b.layer?.borderColor = tomato.withAlphaComponent(0.35).cgColor
                b.attributedTitle = NSAttributedString(string: title, attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: tomato
                ])
            }
            return b
        }

        startBtn.frame = NSRect(x: 12, y: 10, width: 100, height: 28)
        let s = makeBtn("▶  Start", filled: true)
        s.frame = startBtn.frame
        s.target = self
        s.action = #selector(startPause)
        card.addSubview(s)
        // keep ref
        // We'll use tag-based lookup
        s.tag = 1
        startBtn.removeFromSuperview()

        let skip = makeBtn("⏭  Skip", filled: false)
        skip.frame = NSRect(x: 120, y: 10, width: 68, height: 28)
        skip.target = self
        skip.action = #selector(skipPhase)
        card.addSubview(skip)

        let reset = makeBtn("↺", filled: false)
        reset.frame = NSRect(x: 196, y: 10, width: 50, height: 28)
        reset.target = self
        reset.action = #selector(resetTimer)
        card.addSubview(reset)

        contentView = card
    }

    func updateUI() {
        let pt = PomodoroTimer.shared
        let dots = String(repeating: "🍅", count: pt.completedSessions % 4)
            + String(repeating: "○", count: 4 - pt.completedSessions % 4)
        phaseLabel.stringValue = "\(pt.phase.emoji)  \(pt.phase.label)"
        timeLabel.stringValue = pt.phase == .idle
            ? String(format: "%02d:00", pt.workMinutes) : pt.timeString
        sessionDots.stringValue = dots

        if let card = contentView,
           let btn = card.viewWithTag(1) as? NSButton {
            let title = pt.isRunning ? "⏸  Pause" : "▶  Start"
            let tomato = NSColor(red: 0.9, green: 0.35, blue: 0.25, alpha: 1)
            btn.attributedTitle = NSAttributedString(string: title, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.white
            ])
            btn.layer?.backgroundColor = tomato.cgColor
        }
    }

    @objc private func startPause() {
        let pt = PomodoroTimer.shared
        pt.isRunning ? pt.pause() : pt.start()
        updateUI()
    }

    @objc private func skipPhase() {
        PomodoroTimer.shared.skip()
        updateUI()
    }

    @objc private func resetTimer() {
        PomodoroTimer.shared.reset()
        updateUI()
    }
}
