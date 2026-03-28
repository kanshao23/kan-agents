import Foundation

class ReminderScheduler {
    static let shared = ReminderScheduler()
    var onTaskDue: ((TaskReminder) -> Void)?
    private var timer: Timer?
    private var snoozed: [UUID: Date] = [:]
    private var firedToday: Set<String> = []  // "uuid-YYYY-MM-DD"

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.check()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func snooze(_ task: TaskReminder, minutes: Int = 10) {
        snoozed[task.id] = Date().addingTimeInterval(Double(minutes) * 60)
    }

    private func check() {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let today = ISO8601DateFormatter().string(from: now).prefix(10)

        for task in TaskStore.shared.tasks where task.enabled {
            let fireKey = "\(task.id)-\(today)"
            if firedToday.contains(fireKey) { continue }
            if task.hour == hour && task.minute == minute {
                // Check snooze
                if let snoozeUntil = snoozed[task.id], now < snoozeUntil { continue }
                snoozed.removeValue(forKey: task.id)
                firedToday.insert(fireKey)
                DispatchQueue.main.async { self.onTaskDue?(task) }
            }
        }

        // Reset firedToday at midnight
        let todayStr = String(today)
        firedToday = firedToday.filter { $0.hasSuffix(todayStr) }
    }
}
