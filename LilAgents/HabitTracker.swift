import Foundation

struct Habit: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var completions: [String] = []   // "YYYY-MM-DD" strings
    var reminderHour: Int? = nil
    var reminderMinute: Int? = nil

    var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var isDoneToday: Bool {
        completions.contains(todayKey)
    }

    var streak: Int {
        var count = 0
        var date = Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        while true {
            let key = f.string(from: date)
            if completions.contains(key) {
                count += 1
                date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
            } else {
                break
            }
        }
        return count
    }

    mutating func toggleToday() {
        let key = todayKey
        if let idx = completions.firstIndex(of: key) {
            completions.remove(at: idx)
        } else {
            completions.append(key)
        }
    }
}

class HabitStore {
    static let shared = HabitStore()
    private let key = "dailyHabits"

    var habits: [Habit] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([Habit].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    func add(_ habit: Habit) {
        var all = habits; all.append(habit); habits = all
    }

    func remove(at index: Int) {
        var all = habits
        guard index < all.count else { return }
        all.remove(at: index)
        habits = all
    }

    func toggleToday(at index: Int) -> Bool {
        var all = habits
        guard index < all.count else { return false }
        let wasDone = all[index].isDoneToday
        all[index].toggleToday()
        habits = all
        return !wasDone  // returns true if just completed
    }
}
