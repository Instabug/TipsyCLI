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
    
//    func testClassName() throws {
//        let command = RunCommand()
//        let names = command.createScenarioProvidersArrayFrom(classesNames: "Class1, Class2, Class3")
//        XCTAssertEqual(names, "Class1.self, Class2.self, Class3.self")
//    }
//    
//    func testClassName2() throws {
//        let command = RunCommand()
//        let names = command.createScenarioProvidersArrayFrom(classesNames: "Class1,Class2,Class3")
//        XCTAssertEqual(names, "Class1.self, Class2.self, Class3.self")
//    }

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
