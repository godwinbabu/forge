import Testing
import Foundation
@testable import ForgeKit

@Suite("SNIExtractor Tests")
struct SNIExtractorTests {
    static func buildClientHello(sni: String) -> Data {
        let hostnameBytes = Array(sni.utf8)
        let hostnameLen = hostnameBytes.count

        var sniExt = Data()
        sniExt.append(contentsOf: [0x00, 0x00])
        let sniListLen = hostnameLen + 3
        let sniExtLen = sniListLen + 2
        sniExt.append(contentsOf: UInt16(sniExtLen).bigEndianBytes)
        sniExt.append(contentsOf: UInt16(sniListLen).bigEndianBytes)
        sniExt.append(0x00)
        sniExt.append(contentsOf: UInt16(hostnameLen).bigEndianBytes)
        sniExt.append(contentsOf: hostnameBytes)

        var extensions = Data()
        extensions.append(contentsOf: UInt16(sniExt.count).bigEndianBytes)
        extensions.append(sniExt)

        var body = Data()
        body.append(contentsOf: [0x03, 0x03])
        body.append(Data(repeating: 0x00, count: 32))
        body.append(0x00)
        body.append(contentsOf: [0x00, 0x02, 0x00, 0xFF])
        body.append(contentsOf: [0x01, 0x00])
        body.append(extensions)

        var handshake = Data()
        handshake.append(0x01)
        let bodyLen = body.count
        handshake.append(UInt8((bodyLen >> 16) & 0xFF))
        handshake.append(UInt8((bodyLen >> 8) & 0xFF))
        handshake.append(UInt8(bodyLen & 0xFF))
        handshake.append(body)

        var record = Data()
        record.append(0x16)
        record.append(contentsOf: [0x03, 0x01])
        record.append(contentsOf: UInt16(handshake.count).bigEndianBytes)
        record.append(handshake)
        return record
    }

    @Test func extractsSNIFromValidClientHello() {
        let data = Self.buildClientHello(sni: "reddit.com")
        #expect(SNIExtractor.extractHostname(from: data) == "reddit.com")
    }

    @Test func extractsLongHostname() {
        let data = Self.buildClientHello(sni: "subdomain.example.co.uk")
        #expect(SNIExtractor.extractHostname(from: data) == "subdomain.example.co.uk")
    }

    @Test func returnsNilForNonTLSData() {
        let data = Data([0x47, 0x45, 0x54, 0x20])
        #expect(SNIExtractor.extractHostname(from: data) == nil)
    }

    @Test func returnsNilForEmptyData() {
        #expect(SNIExtractor.extractHostname(from: Data()) == nil)
    }

    @Test func returnsNilForTruncatedData() {
        let data = Data([0x16, 0x03, 0x01])
        #expect(SNIExtractor.extractHostname(from: data) == nil)
    }
}

extension UInt16 {
    var bigEndianBytes: [UInt8] {
        [UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)]
    }
}
