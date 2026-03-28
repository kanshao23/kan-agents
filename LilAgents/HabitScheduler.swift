import Foundation

class HabitScheduler {
    static let shared = HabitScheduler()
    var onHabitDue: ((Habit) -> Void)?
    private var timer: Timer?
    private var firedToday: Set<String> = []  // "uuid-YYYY-MM-DD"

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.check()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func check() {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let today = String(ISO8601DateFormatter().string(from: now).prefix(10))

        for habit in HabitStore.shared.habits {
            guard let rh = habit.reminderHour, let rm = habit.reminderMinute else { continue }
            guard !habit.isDoneToday else { continue }  // already done, don't nag
            let key = "\(habit.id)-\(today)"
            if firedToday.contains(key) { continue }
            if rh == hour && rm == minute {
                firedToday.insert(key)
                DispatchQueue.main.async { self.onHabitDue?(habit) }
            }
        }

        // Drop stale keys from previous days
        firedToday = firedToday.filter { $0.hasSuffix(today) }
    }
}
