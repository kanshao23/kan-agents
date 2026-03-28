import AppKit

// MARK: - 30-day heatmap

private class HabitHeatmapView: NSView {
    var completions: [String] = [] { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        let sq: CGFloat = 7; let gap: CGFloat = 2; let step = sq + gap

        for i in 0..<30 {
            let date = cal.date(byAdding: .day, value: -(29 - i), to: Date())!
            let done = completions.contains(f.string(from: date))
            let rect = NSRect(x: CGFloat(i) * step, y: 0, width: sq, height: sq)
            let color: NSColor = done
                ? NSColor.systemGreen.withAlphaComponent(0.75)
                : NSColor(white: 0.5, alpha: 0.15)
            color.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
        }
    }
}

// MARK: - HabitWindow

class HabitWindow: NSWindow, NSTableViewDataSource, NSTableViewDelegate {
    static var shared: HabitWindow?

    var onHabitCompleted: (() -> Void)?

    private let tableView = NSTableView()
    private let emojiField = NSTextField()
    private let nameField = NSTextField()
    private let timePicker = NSDatePicker()
    private let timeToggle = NSButton(checkboxWithTitle: "提醒时间", target: nil, action: nil)

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
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
        let W: CGFloat = 420
        let content = NSView(frame: contentLayoutRect)
        content.autoresizingMask = [.width, .height]

        // Header
        let titleLabel = NSTextField(labelWithString: "习惯打卡")
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.frame = NSRect(x: 14, y: 462, width: 200, height: 22)
        content.addSubview(titleLabel)

        let f = DateFormatter(); f.dateFormat = "EEEE · M月d日"
        let dateLabel = NSTextField(labelWithString: f.string(from: Date()))
        dateLabel.font = NSFont.systemFont(ofSize: 11)
        dateLabel.textColor = .secondaryLabelColor
        dateLabel.frame = NSRect(x: 14, y: 444, width: 300, height: 16)
        content.addSubview(dateLabel)

        // Table
        let col = NSTableColumn(identifier: .init("habit"))
        col.width = W - 24
        tableView.addTableColumn(col)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil
        tableView.rowHeight = 70
        tableView.intercellSpacing = NSSize(width: 0, height: 6)
        tableView.selectionHighlightStyle = .none
        tableView.backgroundColor = .clear
        tableView.allowsMultipleSelection = false

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.frame = NSRect(x: 12, y: 118, width: W - 24, height: 318)
        scroll.autoresizingMask = [.width, .height]
        content.addSubview(scroll)

        // Separator
        let sep = NSBox(); sep.boxType = .separator
        sep.frame = NSRect(x: 12, y: 116, width: W - 24, height: 1)
        content.addSubview(sep)

        // Section label
        let newLabel = NSTextField(labelWithString: "添加新习惯")
        newLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        newLabel.textColor = .secondaryLabelColor
        newLabel.frame = NSRect(x: 14, y: 96, width: 200, height: 16)
        content.addSubview(newLabel)

        // Input row
        emojiField.frame = NSRect(x: 14, y: 64, width: 36, height: 26)
        emojiField.placeholderString = "😀"
        emojiField.alignment = .center
        emojiField.font = NSFont.systemFont(ofSize: 16)
        content.addSubview(emojiField)

        nameField.frame = NSRect(x: 56, y: 64, width: 152, height: 26)
        nameField.placeholderString = "习惯名称"
        nameField.target = self
        nameField.action = #selector(addHabit)
        content.addSubview(nameField)

        timeToggle.target = self
        timeToggle.action = #selector(timeToggleChanged)
        timeToggle.frame = NSRect(x: 216, y: 66, width: 80, height: 22)
        content.addSubview(timeToggle)

        timePicker.frame = NSRect(x: 298, y: 64, width: 108, height: 26)
        timePicker.datePickerStyle = .textFieldAndStepper
        timePicker.datePickerElements = [.hourMinute]
        timePicker.dateValue = Date()
        timePicker.isEnabled = false
        content.addSubview(timePicker)

        let addBtn = NSButton(title: "添加", target: self, action: #selector(addHabit))
        addBtn.bezelStyle = .rounded
        addBtn.frame = NSRect(x: 14, y: 24, width: 70, height: 28)
        content.addSubview(addBtn)

        let removeBtn = NSButton(title: "删除选中", target: self, action: #selector(removeHabit))
        removeBtn.bezelStyle = .rounded
        removeBtn.frame = NSRect(x: 92, y: 24, width: 90, height: 28)
        content.addSubview(removeBtn)

        contentView = content
    }

    @objc private func timeToggleChanged() {
        timePicker.isEnabled = timeToggle.state == .on
    }

    func reload() { tableView.reloadData() }

    @objc private func addHabit() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let emoji = emojiField.stringValue.isEmpty ? "✅" : emojiField.stringValue
        var h = Habit(name: name, emoji: emoji)
        if timeToggle.state == .on {
            let cal = Calendar.current
            h.reminderHour = cal.component(.hour, from: timePicker.dateValue)
            h.reminderMinute = cal.component(.minute, from: timePicker.dateValue)
        }
        HabitStore.shared.add(h)
        nameField.stringValue = ""
        emojiField.stringValue = ""
        timeToggle.state = .off
        timePicker.isEnabled = false
        reload()
    }

    @objc private func removeHabit() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        HabitStore.shared.remove(at: row)
        reload()
    }

    @objc func toggleHabit(_ sender: NSButton) {
        let row = sender.tag
        let justCompleted = HabitStore.shared.toggleToday(at: row)
        reload()
        if justCompleted { onHabitCompleted?() }
    }

    // MARK: - DataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        HabitStore.shared.habits.count
    }

    // MARK: - Delegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let habit = HabitStore.shared.habits[row]
        let W: CGFloat = tableColumn?.width ?? 396
        let H: CGFloat = 66

        let card = NSView(frame: NSRect(x: 0, y: 2, width: W, height: H))
        card.wantsLayer = true
        let isDone = habit.isDoneToday
        card.layer?.backgroundColor = isDone
            ? NSColor.systemGreen.withAlphaComponent(0.07).cgColor
            : NSColor(white: 0.5, alpha: 0.04).cgColor
        card.layer?.cornerRadius = 10
        card.layer?.borderWidth = 1
        card.layer?.borderColor = isDone
            ? NSColor.systemGreen.withAlphaComponent(0.22).cgColor
            : NSColor(white: 0.5, alpha: 0.1).cgColor

        // Emoji
        let emojiLabel = NSTextField(labelWithString: habit.emoji)
        emojiLabel.font = NSFont.systemFont(ofSize: 26)
        emojiLabel.frame = NSRect(x: 10, y: H / 2 - 15, width: 36, height: 30)
        card.addSubview(emojiLabel)

        // Name
        let nameLabel = NSTextField(labelWithString: habit.name)
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = isDone ? .secondaryLabelColor : .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.frame = NSRect(x: 52, y: H - 26, width: 210, height: 18)
        card.addSubview(nameLabel)

        // Streak badge
        let s = habit.streak
        let streakText = s > 0 ? "🔥 \(s) 天连续" : "今日开始"
        let streakLabel = NSTextField(labelWithString: streakText)
        streakLabel.font = NSFont.systemFont(ofSize: 10, weight: s >= 3 ? .semibold : .regular)
        streakLabel.textColor = s > 0 ? .systemOrange : .tertiaryLabelColor
        streakLabel.frame = NSRect(x: 52, y: H - 42, width: 130, height: 14)
        card.addSubview(streakLabel)

        // Optional reminder time tag
        if let rh = habit.reminderHour, let rm = habit.reminderMinute {
            let timeLabel = NSTextField(labelWithString: String(format: "⏰ %02d:%02d", rh, rm))
            timeLabel.font = NSFont.systemFont(ofSize: 10)
            timeLabel.textColor = .tertiaryLabelColor
            timeLabel.frame = NSRect(x: 184, y: H - 42, width: 70, height: 14)
            card.addSubview(timeLabel)
        }

        // 30-day heatmap
        let heatmap = HabitHeatmapView(frame: NSRect(x: 52, y: 8, width: 270, height: 10))
        heatmap.completions = habit.completions
        card.addSubview(heatmap)

        // Done / Mark button
        let doneBtn = NSButton()
        doneBtn.isBordered = false
        doneBtn.wantsLayer = true
        doneBtn.tag = row
        doneBtn.target = self
        doneBtn.action = #selector(toggleHabit(_:))
        doneBtn.layer?.cornerRadius = 13

        if isDone {
            doneBtn.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.85).cgColor
            doneBtn.attributedTitle = NSAttributedString(string: "✓ 已打卡", attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.white
            ])
        } else {
            doneBtn.layer?.backgroundColor = NSColor.clear.cgColor
            doneBtn.layer?.borderWidth = 1.5
            doneBtn.layer?.borderColor = NSColor(white: 0.5, alpha: 0.3).cgColor
            doneBtn.attributedTitle = NSAttributedString(string: "打卡", attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
        }
        doneBtn.frame = NSRect(x: W - 72, y: H / 2 - 13, width: 62, height: 26)
        card.addSubview(doneBtn)

        return card
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 70 }
}
