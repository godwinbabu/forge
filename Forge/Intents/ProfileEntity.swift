import AppIntents

struct ProfileEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Profile")
    static let defaultQuery = ProfileQuery()

    var id: String
    var name: String
    var icon: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: icon))
    }
}

struct ProfileQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ProfileEntity] {
        let defaults = UserDefaults(suiteName: "group.app.forge")
        guard let data = defaults?.data(forKey: "sharedProfiles"),
              let profiles = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return []
        }
        return profiles
            .filter { identifiers.contains($0["id"] ?? "") }
            .map { ProfileEntity(id: $0["id"] ?? "", name: $0["name"] ?? "", icon: $0["icon"] ?? "flame") }
    }

    func suggestedEntities() async throws -> [ProfileEntity] {
        let defaults = UserDefaults(suiteName: "group.app.forge")
        guard let data = defaults?.data(forKey: "sharedProfiles"),
              let profiles = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return []
        }
        return profiles.map {
            ProfileEntity(id: $0["id"] ?? "", name: $0["name"] ?? "", icon: $0["icon"] ?? "flame")
        }
    }
}
