import Foundation

struct HistoryStore {
    private static var dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("com.lilagents.app/history", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    static func save(_ history: [AgentMessage], characterID: String, provider: AgentProvider) {
        guard !characterID.isEmpty else { return }
        let url = dir.appendingPathComponent("\(characterID)-\(provider.rawValue).json")
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func load(characterID: String, provider: AgentProvider) -> [AgentMessage] {
        guard !characterID.isEmpty else { return [] }
        let url = dir.appendingPathComponent("\(characterID)-\(provider.rawValue).json")
        guard let data = try? Data(contentsOf: url),
              let history = try? JSONDecoder().decode([AgentMessage].self, from: data)
        else { return [] }
        return history
    }

    static func clear(characterID: String, provider: AgentProvider) {
        guard !characterID.isEmpty else { return }
        let url = dir.appendingPathComponent("\(characterID)-\(provider.rawValue).json")
        try? FileManager.default.removeItem(at: url)
    }
}
