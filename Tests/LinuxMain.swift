import XCTest

import TipsyCLITests

var tests = [XCTestCaseEntry]()
tests += TipsyCLITests.allTests()
XCTMain(tests)