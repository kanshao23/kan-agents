import Foundation

class GeminiSession: NSObject, AgentSession {
    private(set) var isRunning = false
    private(set) var isBusy = false
    var history: [AgentMessage] = []

    var onText: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onToolUse: ((String, [String: Any]) -> Void)?
    var onToolResult: ((String, Bool) -> Void)?
    var onSessionReady: (() -> Void)?
    var onTurnComplete: (() -> Void)?
    var onProcessExit: (() -> Void)?

    private var process: Process?
    private var stdinPipe: Pipe?
    private var outputBuffer = ""
    private static var cachedBinaryPath: String?

    func start() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if let cached = Self.cachedBinaryPath {
            launchProcess(binary: cached)
            return
        }
        ShellEnvironment.findBinary(name: "gemini", fallbackPaths: [
            "\(home)/.local/bin/gemini",
            "/usr/local/bin/gemini",
            "/opt/homebrew/bin/gemini"
        ]) { [weak self] path in
            guard let self = self else { return }
            if let binary = path {
                Self.cachedBinaryPath = binary
                self.launchProcess(binary: binary)
            } else {
                let msg = "Gemini CLI not found.\n\n\(AgentProvider.gemini.installInstructions)"
                self.onError?(msg)
                self.history.append(AgentMessage(role: .error, text: msg))
            }
        }
    }

    private func launchProcess(binary: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = []
        proc.environment = ShellEnvironment.processEnvironment()

        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr
        stdinPipe = stdin

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.handleChunk(text) }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            DispatchQueue.main.async { self?.onError?(trimmed) }
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.isBusy = false
                self?.onProcessExit?()
            }
        }

        process = proc
        do {
            try proc.run()
            isRunning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.onSessionReady?()
            }
        } catch {
            onError?("Failed to launch Gemini: \(error.localizedDescription)")
        }
    }

    private func handleChunk(_ text: String) {
        outputBuffer += text
        onText?(text)
        isBusy = true
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(finalizeTurn), object: nil)
        perform(#selector(finalizeTurn), with: nil, afterDelay: 1.2)
    }

    @objc private func finalizeTurn() {
        guard isBusy else { return }
        let text = outputBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            history.append(AgentMessage(role: .assistant, text: text))
        }
        outputBuffer = ""
        isBusy = false
        onTurnComplete?()
    }

    func send(message: String) {
        guard isRunning, let stdin = stdinPipe else {
            onError?("Session not running"); return
        }
        history.append(AgentMessage(role: .user, text: message))
        isBusy = true
        outputBuffer = ""
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(finalizeTurn), object: nil)
        if let data = (message + "\n").data(using: .utf8) {
            stdin.fileHandleForWriting.write(data)
        }
    }

    func terminate() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(finalizeTurn), object: nil)
        stdinPipe?.fileHandleForWriting.closeFile()
        process?.terminate()
        process = nil
        isRunning = false
        isBusy = false
    }
}
