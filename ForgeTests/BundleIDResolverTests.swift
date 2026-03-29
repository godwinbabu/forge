import Testing
import Foundation
@testable import ForgeKit

@Suite("BundleIDResolver Tests")
struct BundleIDResolverTests {

    @Test func resolvesFinderBundleID() {
        let path = "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"
        let bundleID = BundleIDResolver.bundleID(forExecutableAt: path)
        #expect(bundleID == "com.apple.finder")
    }

    @Test func resolvesFromAppPath() {
        let path = "/Applications/Safari.app/Contents/MacOS/Safari"
        let bundleID = BundleIDResolver.bundleID(forExecutableAt: path)
        #expect(bundleID == "com.apple.Safari")
    }

    @Test func returnsNilForNonAppExecutable() {
        let path = "/usr/bin/ls"
        let bundleID = BundleIDResolver.bundleID(forExecutableAt: path)
        #expect(bundleID == nil)
    }

    @Test func returnsNilForNonexistentPath() {
        let path = "/nonexistent/path/App.app/Contents/MacOS/binary"
        let bundleID = BundleIDResolver.bundleID(forExecutableAt: path)
        #expect(bundleID == nil)
    }
}
