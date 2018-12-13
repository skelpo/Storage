import XCTest
import Vapor
@testable import Storage

final class StorageTests: XCTestCase {
    let app: Application = {
        var services = Services.default()
        services.register(LocalStorage.self)
        
        let config = Config.default()
        let env = try! Environment.detect()
        
        return try! Application(config: config, environment: env, services: services)
    }()
    
    let data = """
    # Storage

    Test data for the `LocalStorage` instance so we can test it.

    I could use Lorum Ipsum, or I could just sit here and write jibberish like I am now. It might take long, but oh well.

    Listing to the Piano Guys right now.

    Ok, that should be enough bytes for anyone. Unless we are short of the chunk size. I want enough data for at least two chunks of data.

    # Section 2

    ^><<>@<^<>^<>^<>^<>^<>^<>^<>^ open mouth 😮. Hmm, I wonder how that will work
    Maybe if I ran a byte count I could stop typing. But I'm too lazy.

    I hope this is enough.

    # Final
    """.data(using: .utf8)!
    
    let path = FileManager.default.currentDirectoryPath
    
    func testStore()throws {
        let storage = try self.app.make(LocalStorage.self)
        let file = File(data: self.data, filename: "test.md")
        
        let path = try storage.store(file: file, at: self.path).wait()
        
        XCTAssertEqual(path, self.path + "/" + file.filename)
        
        try FileManager.default.removeItem(atPath: path)
    }
    
    func testFetch()throws {
        let storage = try self.app.make(LocalStorage.self)
        let f = File(data: self.data, filename: "test.md")
        let path = try storage.store(file: f, at: self.path).wait()
        
        let file = try storage.fetch(file: path).wait()
        
        XCTAssertEqual(file.data, self.data)
        XCTAssertEqual(file.filename, "test.md")
        
        try FileManager.default.removeItem(atPath: path)
    }
    
    static var allTests: [(String, (StorageTests) -> ()throws -> ())] = [
        ("testStore", testStore),
        ("testFetch", testFetch)
    ]
}
