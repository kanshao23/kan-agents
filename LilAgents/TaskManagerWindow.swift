import AppKit

class TaskManagerWindow: NSWindow, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let addButton = NSButton()
    private let removeButton = NSButton()
    private let titleField = NSTextField()
    private let timePicker = NSDatePicker()

    static func show() {
        let win = TaskManagerWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Daily Reminders"
        win.center()
        win.isReleasedWhenClosed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupUI()
        reload()
    }

    private func setupUI() {
        let content = NSView(frame: contentLayoutRect)
        content.autoresizingMask = [.width, .height]

        // Table
        let timeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeCol.title = "Time"
        timeCol.width = 70
        let titleCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleCol.title = "Task"
        titleCol.width = 220
        let enabledCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        enabledCol.title = "On"
        enabledCol.width = 40

        tableView.addTableColumn(timeCol)
        tableView.addTableColumn(titleCol)
        tableView.addTableColumn(enabledCol)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.frame = NSRect(x: 12, y: 90, width: 376, height: 230)
        scrollView.autoresizingMask = [.width, .height]
        content.addSubview(scrollView)

        // Input row
        let timeLabel = NSTextField(labelWithString: "Time:")
        timeLabel.frame = NSRect(x: 12, y: 56, width: 40, height: 22)
        content.addSubview(timeLabel)

        timePicker.frame = NSRect(x: 56, y: 54, width: 90, height: 26)
        timePicker.datePickerStyle = .textFieldAndStepper
        timePicker.datePickerElements = [.hourMinute]
        timePicker.dateValue = Date()
        content.addSubview(timePicker)

        let taskLabel = NSTextField(labelWithString: "Task:")
        taskLabel.frame = NSRect(x: 156, y: 56, width: 40, height: 22)
        content.addSubview(taskLabel)

        titleField.frame = NSRect(x: 198, y: 54, width: 190, height: 26)
        titleField.placeholderString = "e.g. Take a break"
        titleField.delegate = self
        titleField.target = self
        titleField.action = #selector(addTask)
        content.addSubview(titleField)

        // Buttons
        addButton.title = "Add"
        addButton.bezelStyle = .rounded
        addButton.frame = NSRect(x: 12, y: 16, width: 80, height: 28)
        addButton.target = self
        addButton.action = #selector(addTask)
        content.addSubview(addButton)

        removeButton.title = "Remove"
        removeButton.bezelStyle = .rounded
        removeButton.frame = NSRect(x: 100, y: 16, width: 80, height: 28)
        removeButton.target = self
        removeButton.action = #selector(removeTask)
        content.addSubview(removeButton)

        contentView = content
    }

    private func reload() {
        tableView.reloadData()
    }

    @objc private func addTask() {
        let name = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let cal = Calendar.current
        let h = cal.component(.hour, from: timePicker.dateValue)
        let m = cal.component(.minute, from: timePicker.dateValue)
        let task = TaskReminder(title: name, hour: h, minute: m)
        TaskStore.shared.add(task)
        titleField.stringValue = ""
        reload()
    }

    @objc private func removeTask() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        TaskStore.shared.remove(at: row)
        reload()
    }

    @objc private func toggleEnabled(_ sender: NSButton) {
        let row = sender.tag
        var task = TaskStore.shared.tasks[row]
        task.enabled = sender.state == .on
        TaskStore.shared.update(task)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        TaskStore.shared.tasks.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let task = TaskStore.shared.tasks[row]
        let id = tableColumn?.identifier.rawValue ?? ""

        switch id {
        case "time":
            let tf = NSTextField(labelWithString: task.timeString)
            tf.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            return tf
        case "title":
            return NSTextField(labelWithString: task.title)
        case "enabled":
            let cb = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleEnabled(_:)))
            cb.state = task.enabled ? .on : .off
            cb.tag = row
            return cb
        default:
            return nil
        }
    }
}
