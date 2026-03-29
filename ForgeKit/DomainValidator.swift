import Foundation

public enum DomainValidator {
    public static func validate(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, trimmed.contains(".") else { return nil }
        return trimmed
    }

    public static func validateList(_ inputs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for input in inputs {
            guard let validated = validate(input), !seen.contains(validated) else { continue }
            seen.insert(validated)
            result.append(validated)
        }
        return result
    }
}
