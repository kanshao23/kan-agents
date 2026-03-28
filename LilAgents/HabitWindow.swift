import AppKit

class HabitWindow: NSWindow, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    static var shared: HabitWindow?

    static func show() {
        if shared == nil {
            shared = HabitWindow()
        }
        shared?.reload()
        shared?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    var onHabitCompleted: (() -> Void)?

    private let tableView = NSTableView()
    private let emojiField = NSTextField()
    private let nameField = NSTextField()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        title = "Habit Tracker"
        isReleasedWhenClosed = false
        center()
        setupUI()
        reload()
    }

    private func setupUI() {
        let content = NSView(frame: contentLayoutRect)
        content.autoresizingMask = [.width, .height]

        // Today header
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        let todayLabel = NSTextField(labelWithString: "Today · " + f.string(from: Date()))
        todayLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        todayLabel.textColor = .secondaryLabelColor
        todayLabel.frame = NSRect(x: 14, y: 340, width: 352, height: 22)
        content.addSubview(todayLabel)

        // Table columns
        let checkCol = NSTableColumn(identifier: .init("check"))
        checkCol.title = "Done"; checkCol.width = 46
        let emojiCol = NSTableColumn(identifier: .init("emoji"))
        emojiCol.title = ""; emojiCol.width = 30
        let nameCol = NSTableColumn(identifier: .init("name"))
        nameCol.title = "Habit"; nameCol.width = 180
        let streakCol = NSTableColumn(identifier: .init("streak"))
        streakCol.title = "Streak"; streakCol.width = 70

        [checkCol, emojiCol, nameCol, streakCol].forEach { tableView.addTableColumn($0) }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 36
        tableView.allowsMultipleSelection = false

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.frame = NSRect(x: 12, y: 90, width: 356, height: 240)
        scroll.autoresizingMask = [.width, .height]
        content.addSubview(scroll)

        // Add habit row
        let addLabel = NSTextField(labelWithString: "New habit:")
        addLabel.frame = NSRect(x: 12, y: 60, width: 70, height: 22)
        content.addSubview(addLabel)

        emojiField.frame = NSRect(x: 84, y: 58, width: 36, height: 26)
        emojiField.placeholderString = "😀"
        emojiField.alignment = .center
        content.addSubview(emojiField)

        nameField.frame = NSRect(x: 126, y: 58, width: 172, height: 26)
        nameField.placeholderString = "e.g. Drink water"
        nameField.delegate = self
        nameField.target = self
        nameField.action = #selector(addHabit)
        content.addSubview(nameField)

        let addBtn = NSButton(title: "Add", target: self, action: #selector(addHabit))
        addBtn.bezelStyle = .rounded
        addBtn.frame = NSRect(x: 304, y: 57, width: 64, height: 28)
        content.addSubview(addBtn)

        let removeBtn = NSButton(title: "Remove", target: self, action: #selector(removeHabit))
        removeBtn.bezelStyle = .rounded
        removeBtn.frame = NSRect(x: 12, y: 16, width: 80, height: 28)
        content.addSubview(removeBtn)

        // Streak legend
        let legend = NSTextField(labelWithString: "🔥 = current streak days")
        legend.font = NSFont.systemFont(ofSize: 11)
        legend.textColor = .tertiaryLabelColor
        legend.frame = NSRect(x: 100, y: 20, width: 270, height: 18)
        content.addSubview(legend)

        contentView = content
    }

    func reload() {
        tableView.reloadData()
    }

    @objc private func addHabit() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let emoji = emojiField.stringValue.isEmpty ? "✅" : emojiField.stringValue
        HabitStore.shared.add(Habit(name: name, emoji: emoji))
        nameField.stringValue = ""
        emojiField.stringValue = ""
        reload()
    }

    @objc private func removeHabit() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        HabitStore.shared.remove(at: row)
        reload()
    }

    @objc private func toggleHabit(_ sender: NSButton) {
        let row = sender.tag
        let justCompleted = HabitStore.shared.toggleToday(at: row)
        reload()
        if justCompleted { onHabitCompleted?() }
    }

    // MARK: DataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        HabitStore.shared.habits.count
    }

    // MARK: Delegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let habit = HabitStore.shared.habits[row]
        switch tableColumn?.identifier.rawValue {
        case "check":
            let btn = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleHabit(_:)))
            btn.state = habit.isDoneToday ? .on : .off
            btn.tag = row
            return btn
        case "emoji":
            let tf = NSTextField(labelWithString: habit.emoji)
            tf.font = NSFont.systemFont(ofSize: 18)
            tf.alignment = .center
            return tf
        case "name":
            let tf = NSTextField(labelWithString: habit.name)
            tf.font = NSFont.systemFont(ofSize: 13)
            tf.textColor = habit.isDoneToday ? .secondaryLabelColor : .labelColor
            return tf
        case "streak":
            let s = habit.streak
            let text = s > 0 ? "🔥 \(s)d" : "—"
            let tf = NSTextField(labelWithString: text)
            tf.font = NSFont.systemFont(ofSize: 12, weight: s >= 7 ? .bold : .regular)
            tf.alignment = .center
            return tf
        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 36 }
}
