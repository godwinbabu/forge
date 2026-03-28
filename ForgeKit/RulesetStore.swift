import Foundation

public final class RulesetStore: Sendable {
    private let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("active-ruleset.json")
    }

    public func save(_ ruleset: BlockRuleset) throws {
        let data = try JSONEncoder().encode(ruleset)
        try data.write(to: fileURL, options: .atomic)
    }

    public func load() -> BlockRuleset? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(BlockRuleset.self, from: data)
    }

    public func loadIfActive() -> BlockRuleset? {
        guard let ruleset = load() else { return nil }
        if ruleset.isExpired {
            delete()
            return nil
        }
        return ruleset
    }

    public func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
