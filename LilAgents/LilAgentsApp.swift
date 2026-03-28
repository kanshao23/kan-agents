import SwiftUI
import AppKit
import Sparkle

@main
struct LilAgentsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: LilAgentsController?
    var statusItem: NSStatusItem?
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = LilAgentsController()
        controller?.start()
        NotificationManager.shared.requestPermission()
        setupMenuBar()
        ReminderScheduler.shared.start()
        ReminderScheduler.shared.onTaskDue = { [weak self] task in
            let character = self?.controller?.characters.first(where: { $0.isManuallyVisible })
                ?? self?.controller?.characters.first
            character?.showReminder(task: task)
        }
        PomodoroTimer.shared.onTick = { [weak self] in
            self?.controller?.characters.forEach { $0.updatePomodoroBar() }
            PomodoroWindow.shared?.updateUI()
        }
        PomodoroTimer.shared.onPhaseComplete = { [weak self] phase in
            let character = self?.controller?.characters.first(where: { $0.isManuallyVisible })
                ?? self?.controller?.characters.first
            switch phase {
            case .working:
                character?.showBubble(text: "休息一下！☕", isCompletion: true)
                character?.playCompletionSound()
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { character?.thinkingBubbleWindow?.orderOut(nil) }
            case .shortBreak, .longBreak:
                character?.showBubble(text: "回来工作啦！💻", isCompletion: false)
                character?.playCompletionSound()
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { character?.thinkingBubbleWindow?.orderOut(nil) }
            case .idle:
                break
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.characters.forEach { char in
            char.session?.terminate()
            if !char.characterID.isEmpty {
                UserDefaults.standard.set(Double(char.positionProgress), forKey: "char.\(char.characterID).position")
            }
        }
    }

    // MARK: - Menu Bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "lil agents")
        }

        let menu = NSMenu()

        let char1Item = NSMenuItem(title: "Bruce", action: #selector(toggleChar1), keyEquivalent: "1")
        char1Item.state = .on
        menu.addItem(char1Item)

        let char2Item = NSMenuItem(title: "Jazz", action: #selector(toggleChar2), keyEquivalent: "2")
        char2Item.state = .on
        menu.addItem(char2Item)

        menu.addItem(NSMenuItem.separator())

        let soundItem = NSMenuItem(title: "Sounds", action: #selector(toggleSounds(_:)), keyEquivalent: "")
        soundItem.state = .on
        menu.addItem(soundItem)

        let hotkeyItem = NSMenuItem(title: "Open Chat: ⌘⇧Space", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        // Provider submenu
        let providerItem = NSMenuItem(title: "Provider", action: nil, keyEquivalent: "")
        let providerMenu = NSMenu()
        for (i, provider) in AgentProvider.allCases.enumerated() {
            let item = NSMenuItem(title: provider.displayName, action: #selector(switchProvider(_:)), keyEquivalent: "")
            item.tag = i
            item.state = provider == AgentProvider.current ? .on : .off
            providerMenu.addItem(item)
        }
        providerItem.submenu = providerMenu
        menu.addItem(providerItem)

        // Theme submenu
        let themeItem = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for (i, theme) in PopoverTheme.allThemes.enumerated() {
            let item = NSMenuItem(title: theme.name, action: #selector(switchTheme(_:)), keyEquivalent: "")
            item.tag = i
            item.state = theme.name == PopoverTheme.current.name ? .on : .off
            themeMenu.addItem(item)
        }
        themeMenu.addItem(NSMenuItem.separator())
        let customizeItem = NSMenuItem(title: "Customize Colors…", action: #selector(customizeTheme), keyEquivalent: "")
        themeMenu.addItem(customizeItem)
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        // Display submenu
        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        let displayMenu = NSMenu()
        displayMenu.delegate = self
        let autoItem = NSMenuItem(title: "Auto (Main Display)", action: #selector(switchDisplay(_:)), keyEquivalent: "")
        autoItem.tag = -1
        autoItem.state = .on
        displayMenu.addItem(autoItem)
        displayMenu.addItem(NSMenuItem.separator())
        for (i, screen) in NSScreen.screens.enumerated() {
            let name = screen.localizedName
            let item = NSMenuItem(title: name, action: #selector(switchDisplay(_:)), keyEquivalent: "")
            item.tag = i
            item.state = .off
            displayMenu.addItem(item)
        }
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        // Shrink submenu
        let shrinkItem = NSMenuItem(title: "Idle Shrink", action: nil, keyEquivalent: "")
        let shrinkMenu = NSMenu()

        let shrinkToggle = NSMenuItem(title: "Shrink when idle", action: #selector(toggleIdleShrink(_:)), keyEquivalent: "")
        shrinkToggle.state = WalkerCharacter.shrinkWhenIdle ? .on : .off
        shrinkMenu.addItem(shrinkToggle)

        shrinkMenu.addItem(NSMenuItem.separator())

        let delayOptions: [(String, Double)] = [("10 seconds", 10), ("20 seconds", 20), ("30 seconds", 30), ("60 seconds", 60)]
        for (label, delay) in delayOptions {
            let item = NSMenuItem(title: label, action: #selector(setShrinkDelay(_:)), keyEquivalent: "")
            item.representedObject = delay
            item.state = WalkerCharacter.shrinkDelaySeconds == delay ? .on : .off
            shrinkMenu.addItem(item)
        }

        shrinkItem.submenu = shrinkMenu
        menu.addItem(shrinkItem)

        menu.addItem(NSMenuItem.separator())

        let remindersItem = NSMenuItem(title: "Daily Reminders…", action: #selector(openReminders), keyEquivalent: "")
        menu.addItem(remindersItem)

        let pomodoroItem = NSMenuItem(title: "Pomodoro Timer", action: #selector(togglePomodoro), keyEquivalent: "")
        menu.addItem(pomodoroItem)

        let habitsItem = NSMenuItem(title: "Habit Tracker", action: #selector(openHabits), keyEquivalent: "")
        menu.addItem(habitsItem)

        menu.addItem(NSMenuItem.separator())

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    @objc func switchTheme(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard idx < PopoverTheme.allThemes.count else { return }
        PopoverTheme.current = PopoverTheme.allThemes[idx]

        if let themeMenu = sender.menu {
            for item in themeMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        controller?.characters.forEach { char in
            let wasOpen = char.isIdleForPopover
            if wasOpen { char.popoverWindow?.orderOut(nil) }
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow = nil
            if wasOpen {
                char.createPopoverWindow()
                if let session = char.session, !session.history.isEmpty {
                    char.terminalView?.replayHistory(session.history)
                }
                char.updatePopoverPosition()
                char.popoverWindow?.orderFrontRegardless()
                char.popoverWindow?.makeKey()
                if let terminal = char.terminalView {
                    char.popoverWindow?.makeFirstResponder(terminal.inputField)
                }
            }
        }
    }

    @objc func customizeTheme() {
        let alert = NSAlert()
        alert.messageText = "Custom Theme Colors"
        alert.informativeText = "Choose background and accent colors for the Custom theme."
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")

        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 60))

        let bgLabel = NSTextField(labelWithString: "Background:")
        bgLabel.frame = NSRect(x: 0, y: 34, width: 90, height: 20)
        let bgWell = NSColorWell(frame: NSRect(x: 95, y: 32, width: 44, height: 24))
        bgWell.color = PopoverTheme.customBackground

        let acLabel = NSTextField(labelWithString: "Accent:")
        acLabel.frame = NSRect(x: 150, y: 34, width: 60, height: 20)
        let acWell = NSColorWell(frame: NSRect(x: 215, y: 32, width: 44, height: 24))
        acWell.color = PopoverTheme.customAccent

        panel.addSubview(bgLabel); panel.addSubview(bgWell)
        panel.addSubview(acLabel); panel.addSubview(acWell)
        alert.accessoryView = panel

        if alert.runModal() == .alertFirstButtonReturn {
            PopoverTheme.customBackground = bgWell.color
            PopoverTheme.customAccent = acWell.color
            if PopoverTheme.current.name == "Custom" {
                rebuildPopoversForCurrentTheme()
            }
        }
    }

    private func rebuildPopoversForCurrentTheme() {
        let currentName = PopoverTheme.current.name
        guard let idx = PopoverTheme.allThemes.firstIndex(where: { $0.name == currentName }) else { return }
        PopoverTheme.current = PopoverTheme.allThemes[idx]
        controller?.characters.forEach { char in
            let wasOpen = char.isIdleForPopover
            if wasOpen { char.popoverWindow?.orderOut(nil) }
            char.popoverWindow = nil; char.terminalView = nil; char.thinkingBubbleWindow = nil
            if wasOpen {
                char.createPopoverWindow()
                if let session = char.session, !session.history.isEmpty {
                    char.terminalView?.replayHistory(session.history)
                }
                char.updatePopoverPosition()
                char.popoverWindow?.orderFrontRegardless()
                char.popoverWindow?.makeKey()
                if let t = char.terminalView { char.popoverWindow?.makeFirstResponder(t.inputField) }
            }
        }
    }

    @objc func switchProvider(_ sender: NSMenuItem) {
        let idx = sender.tag
        let allProviders = AgentProvider.allCases
        guard idx < allProviders.count else { return }
        AgentProvider.current = allProviders[idx]

        if let providerMenu = sender.menu {
            for item in providerMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        // Terminate existing sessions and clear UI so title/placeholder update
        controller?.characters.forEach { char in
            char.session?.terminate()
            char.session = nil
            if char.isIdleForPopover {
                char.closePopover()
            }
            // Always clear popover/bubble so they rebuild with new provider title/placeholder
            char.popoverWindow?.orderOut(nil)
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow?.orderOut(nil)
            char.thinkingBubbleWindow = nil
        }
    }

    @objc func switchDisplay(_ sender: NSMenuItem) {
        let idx = sender.tag
        controller?.pinnedScreenIndex = idx

        if let displayMenu = sender.menu {
            for item in displayMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }
    }

    @objc func toggleChar1(_ sender: NSMenuItem) {
        guard let chars = controller?.characters, chars.count > 0 else { return }
        let char = chars[0]
        if char.isManuallyVisible {
            char.setManuallyVisible(false)
            sender.state = .off
        } else {
            char.setManuallyVisible(true)
            sender.state = .on
        }
    }

    @objc func toggleChar2(_ sender: NSMenuItem) {
        guard let chars = controller?.characters, chars.count > 1 else { return }
        let char = chars[1]
        if char.isManuallyVisible {
            char.setManuallyVisible(false)
            sender.state = .off
        } else {
            char.setManuallyVisible(true)
            sender.state = .on
        }
    }

    @objc func toggleDebug(_ sender: NSMenuItem) {
        guard let debugWin = controller?.debugWindow else { return }
        if debugWin.isVisible {
            debugWin.orderOut(nil)
            sender.state = .off
        } else {
            debugWin.orderFrontRegardless()
            sender.state = .on
        }
    }

    @objc func toggleSounds(_ sender: NSMenuItem) {
        WalkerCharacter.soundsEnabled.toggle()
        sender.state = WalkerCharacter.soundsEnabled ? .on : .off
    }

    @objc func toggleIdleShrink(_ sender: NSMenuItem) {
        WalkerCharacter.shrinkWhenIdle.toggle()
        sender.state = WalkerCharacter.shrinkWhenIdle ? .on : .off
    }

    @objc func setShrinkDelay(_ sender: NSMenuItem) {
        guard let delay = sender.representedObject as? Double else { return }
        WalkerCharacter.shrinkDelaySeconds = delay
        if let menu = sender.menu {
            for item in menu.items { item.state = .off }
        }
        sender.state = .on
    }

    @objc func openReminders() {
        TaskManagerWindow.show()
    }

    @objc func togglePomodoro() {
        PomodoroWindow.toggle()
    }

    @objc func openHabits() {
        let win = HabitWindow.shared ?? HabitWindow()
        HabitWindow.shared = win
        win.onHabitCompleted = { [weak self] in
            let character = self?.controller?.characters.first(where: { $0.isManuallyVisible })
                ?? self?.controller?.characters.first
            character?.showBubble(text: "习惯打卡！🎉", isCompletion: true)
            character?.playCompletionSound()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                character?.thinkingBubbleWindow?.orderOut(nil)
            }
        }
        win.reload()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {}
