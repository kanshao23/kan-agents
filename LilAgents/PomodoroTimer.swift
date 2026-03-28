import Foundation

enum PomodoroPhase {
    case idle, working, shortBreak, longBreak

    var label: String {
        switch self {
        case .idle: return "Ready"
        case .working: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var emoji: String {
        switch self {
        case .idle: return "🍅"
        case .working: return "💻"
        case .shortBreak: return "☕"
        case .longBreak: return "🌿"
        }
    }
}

class PomodoroTimer {
    static let shared = PomodoroTimer()

    var workMinutes: Int {
        get { UserDefaults.standard.integer(forKey: "pomodoroWork").nonZero ?? 25 }
        set { UserDefaults.standard.set(newValue, forKey: "pomodoroWork") }
    }
    var shortBreakMinutes: Int {
        get { UserDefaults.standard.integer(forKey: "pomodoroShort").nonZero ?? 5 }
        set { UserDefaults.standard.set(newValue, forKey: "pomodoroShort") }
    }
    var longBreakMinutes: Int {
        get { UserDefaults.standard.integer(forKey: "pomodoroLong").nonZero ?? 15 }
        set { UserDefaults.standard.set(newValue, forKey: "pomodoroLong") }
    }

    private(set) var phase: PomodoroPhase = .idle
    private(set) var secondsRemaining: Int = 0
    private(set) var isRunning = false
    private(set) var completedSessions = 0
    private var timer: Timer?

    var onTick: (() -> Void)?
    var onPhaseComplete: ((PomodoroPhase) -> Void)?

    var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    func start() {
        if phase == .idle {
            phase = .working
            secondsRemaining = workMinutes * 60
        }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        phase = .idle
        secondsRemaining = 0
        completedSessions = 0
        onTick?()
    }

    func skip() {
        advance()
    }

    private func tick() {
        guard secondsRemaining > 0 else {
            advance()
            return
        }
        secondsRemaining -= 1
        onTick?()
    }

    private func advance() {
        let completed = phase
        timer?.invalidate()
        timer = nil
        isRunning = false

        if completed == .working {
            completedSessions += 1
            phase = completedSessions % 4 == 0 ? .longBreak : .shortBreak
            secondsRemaining = (phase == .longBreak ? longBreakMinutes : shortBreakMinutes) * 60
        } else {
            phase = .working
            secondsRemaining = workMinutes * 60
        }

        onPhaseComplete?(completed)
        onTick?()
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
