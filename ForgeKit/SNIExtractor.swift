import Foundation

public enum SNIExtractor: Sendable {
    public static func extractHostname(from data: Data) -> String? {
        guard data.count > 5, data[0] == 0x16 else { return nil }

        let recordLength = Int(data[3]) << 8 | Int(data[4])
        guard data.count >= 5 + recordLength else { return nil }

        guard let offset = parseHandshakeHeader(data: data) else { return nil }
        return findSNIExtension(data: data, startingAt: offset)
    }

    private static func parseHandshakeHeader(data: Data) -> Int? {
        var offset = 5
        guard offset < data.count, data[offset] == 0x01 else { return nil }
        offset += 4

        guard offset + 34 <= data.count else { return nil }
        offset += 34

        guard offset < data.count else { return nil }
        let sessionIDLen = Int(data[offset])
        offset += 1 + sessionIDLen

        guard offset + 2 <= data.count else { return nil }
        let cipherLen = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2 + cipherLen

        guard offset < data.count else { return nil }
        let compressionLen = Int(data[offset])
        offset += 1 + compressionLen

        return offset
    }

    private static func findSNIExtension(data: Data, startingAt start: Int) -> String? {
        var offset = start
        guard offset + 2 <= data.count else { return nil }
        let extensionsLen = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2

        let extensionsEnd = offset + extensionsLen
        guard extensionsEnd <= data.count else { return nil }

        while offset + 4 <= extensionsEnd {
            let extType = Int(data[offset]) << 8 | Int(data[offset + 1])
            let extLen = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            offset += 4

            if extType == 0x0000 {
                return parseServerNameExtension(data: data, offset: offset)
            }
            offset += extLen
        }
        return nil
    }

    private static func parseServerNameExtension(data: Data, offset: Int) -> String? {
        var pos = offset
        guard pos + 2 <= data.count else { return nil }
        pos += 2
        guard pos < data.count else { return nil }
        let nameType = data[pos]
        pos += 1
        guard nameType == 0x00 else { return nil }
        guard pos + 2 <= data.count else { return nil }
        let nameLen = Int(data[pos]) << 8 | Int(data[pos + 1])
        pos += 2
        guard pos + nameLen <= data.count else { return nil }
        return String(data: data[pos..<pos + nameLen], encoding: .utf8)
    }
}
