import XCTest
@testable import Storage

final class StorageTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Storage().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
