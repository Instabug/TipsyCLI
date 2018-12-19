import XCTest
@testable import TipsyCore
import PathKit
import class Foundation.Bundle

final class TipsyCLITests: XCTestCase {
    
    func testTempPathCreation() throws {
        let runCommand = RunCommand()
        let tempPath = runCommand.tempPathFrom(path: Path("test.xcodeproj"))
        XCTAssertEqual(tempPath.string, "test-temp.xcodeproj")
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
      #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
      #else
        return Bundle.main.bundleURL
      #endif
    }

//    static var allTests = [
//        ("testExample", testExample),
//    ]
}
