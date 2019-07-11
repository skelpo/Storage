import XCTest

import StorageTests

var tests = [XCTestCaseEntry]()
tests += StorageTests.__allTests()

XCTMain(tests)
