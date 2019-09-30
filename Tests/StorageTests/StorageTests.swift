import NIO
import XCTest
@testable import Storage

final class StorageTests: XCTestCase {
    let path = FileManager.default.currentDirectoryPath

    var eventLoopGroup: EventLoopGroup! = nil
    var storage: Storage! = nil


    let buffer: ByteBuffer = {
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
        """

        let allocator = ByteBufferAllocator()
        var buffer = allocator.buffer(capacity: data.count)

        buffer.writeString(data)
        return buffer
    }()

    let smallBuffer: ByteBuffer = {
        let data = Data([
            10, 76, 97, 115, 116, 32, 76, 105, 110, 101, 32, 101, 110, 100, 115, 32, 104, 101, 114, 101, 46
        ])

        let allocator = ByteBufferAllocator()
        var buffer = allocator.buffer(capacity: data.count)

        buffer.writeBytes(data)
        return buffer
    }()


    override func setUp() {
        super.setUp()

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.storage = LocalStorage(eventLoop: self.eventLoopGroup.next())
    }

    override func tearDown() {
        do {
            try self.eventLoopGroup.syncShutdownGracefully()
        } catch let error {
            print("ELG SHUTDOWN FAILED: ", error)
        }

        self.storage = nil
        self.eventLoopGroup = nil

        super.tearDown()
    }


    func testStore()throws {
        let file = File(buffer: self.buffer, filename: "test.md")
        
        let path = try self.storage.store(file: file, at: self.path).wait()
        
        XCTAssertEqual(path, self.path + "/" + file.filename)
        
        try XCTAssertNoThrow(FileManager.default.removeItem(atPath: path))
    }
    
    func testPathWithWhitespace()throws {
        try FileManager.default.createDirectory(atPath: self.path + "/Test Files", withIntermediateDirectories: false, attributes: nil)

        let file = File(buffer: self.buffer, filename: "test.md")
        let path = try self.storage.store(file: file, at: self.path + "/Test Files").wait()
        XCTAssertEqual(path, self.path + "/Test Files/" + file.filename)

        let read = try storage.fetch(file: path).wait()
        XCTAssertEqual(read.buffer, self.buffer)

        let data = Data([10, 76, 97, 115, 116, 32, 76, 105, 110, 101, 32, 101, 110, 100, 115, 32, 104, 101, 114, 101, 46])
        let update = try self.storage.write(file: path, with: data).wait()
        XCTAssertEqual(update.filename, "test.md")
        XCTAssertEqual(update.buffer, self.smallBuffer)

        try storage.delete(file: path).wait()
    }
    
    func testFetch()throws {
        let f = File(buffer: self.buffer, filename: "test.md")
        let path = try self.storage.store(file: f, at: self.path).wait()
        
        let file = try self.storage.fetch(file: path).wait()

        XCTAssertEqual(file.buffer, self.buffer)
        XCTAssertEqual(file.filename, "test.md")
        
        try FileManager.default.removeItem(atPath: path)
    }
    
    func testWrite()throws {
        let f = File(buffer: self.buffer, filename: "test.md")
        let path = try storage.store(file: f, at: self.path).wait()
        
        let data = Data([10, 76, 97, 115, 116, 32, 76, 105, 110, 101, 32, 101, 110, 100, 115, 32, 104, 101, 114, 101, 46])
        let update = try storage.write(file: path, with: data).wait()
        
        XCTAssertEqual(update.filename, "test.md")
        XCTAssertEqual(update.buffer, self.smallBuffer)
        
        try FileManager.default.removeItem(atPath: path)
    }
    
    func testDelete()throws {
        let f = File(buffer: self.buffer, filename: "test.md")
        let path = try self.storage.store(file: f, at: self.path).wait()
        
        try XCTAssertNoThrow(storage.delete(file: path).wait())
    }
}
