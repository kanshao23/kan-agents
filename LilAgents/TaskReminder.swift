import Foundation

struct TaskReminder: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var hour: Int
    var minute: Int
    var enabled: Bool = true

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

class TaskStore {
    static let shared = TaskStore()
    private let key = "dailyTaskReminders"

    var tasks: [TaskReminder] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([TaskReminder].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    func add(_ task: TaskReminder) {
        var all = tasks
        all.append(task)
        tasks = all
    }

    func remove(at index: Int) {
        var all = tasks
        guard index < all.count else { return }
        all.remove(at: index)
        tasks = all
    }

    func update(_ task: TaskReminder) {
        var all = tasks
        if let idx = all.firstIndex(where: { $0.id == task.id }) {
            all[idx] = task
        }
        tasks = all
    }
}
