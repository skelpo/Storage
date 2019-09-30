import Foundation
import NIO

/// A `Storage` implementation that handles local file storage.
///
/// ## Initializing
///
/// The initializer for `LocalStorage` requires you to pass in a SwiftNIO `EventLoop`, but you can also pass in a custom `FileManager`,
/// a default storage path, and a custom thread pool to run the operations on.
///
///     let storage = LocalStorage(eventLoop: eventLoop, manager: FileManager.default, defaultPath: nil, pool: BlockingIOThreadPool(numberOfThreads: 2))
///
/// Only the `eventLoop` parameter is required. All others have a default value.
///
/// ## Creating New Files
///
/// The `LocalStorage.store(file:at:)` method creats a new file at a given path with the `file.data` value as its contents.
/// If the `LocalStorage.defaultPath` property is not `nil`, you can pass `nil` into the `path` parameter
/// and the file will be stored at the default path. If there is no `path` or `defaultPath`, the `StorageError.pathRequired` error will be thrown.
///
/// The path the file is stored at will be `path` + `file.name`. The `.store` method will handle forward slashes in the path.
///
///     storage.store(file: File(data: Data(), name: "README.md"), at: "/Users/hackerman/projects/AwesomeProject")
///
/// - Note: The `LocalStorage.store` method does _not_ create intermediate directories. The directory you create the file at
///   must already exist or you will get a `StorageError.errno` error.
///
/// ## Getting a File
///
/// The `LocalStorage.fetch(file:)` method uses a `NonBlockingFileIO` instance to stream the data from the file into a byte array.
/// When all the bytes are fetched, they are used to create the `File` instance that is returned.
///
/// The name of the file returned is the last element of the `file` string passed in when it is split at the forward slash characters (`/`).
///
///     storage.fetch(file: "/Users/hackerman/projects/AwesomeProject/README.md")
///
/// ## Updating a File
///
/// The `LocalStorage.write(file:data:options:)` method writes to the specified file using the `Data.write(to:options:)` method.
/// This allows you to customize how to writing happens using the `options` paramater. The operation is run on the worker's event loop using
/// the `BlockingIOThreadPool` instance.
///
/// When the write completes, `LocalStorage.fetch(file:)` is called to get the updated file and return it.
///
///     storage.write(file: "/Users/hackerman/projects/AwesomeProject", with: Data(), options: [.withoutOverwriting])
///
/// ## Deleteing a File
///
/// The `localStorage.delete(file:)` method deletes an existing file by running the `FileManager.deleteItem` method in the `BlockingIOThreadPool`.
///
///     storage.delete(file:  "/Users/hackerman/projects/AwesomeProject")
public struct LocalStorage: Storage {
    
    /// The event loop group that the service lives on.
    public let eventLoop: EventLoop
    
    /// The default path to store files to if no path is passed in.
    public let defaultPath: String?
    
    
    /// The file manager used for checking for a files existance and other validation operations.
    internal let manager: FileManager
    
    /// The thread pool used to asynchronously write to files. Also used to initialize the `NonBlockingFileIO` instance.
    internal let threadPool: NIOThreadPool
    
    /// The file IO interface for creating and reading files.
    internal let io: NonBlockingFileIO
    
    /// The allocator used to create `ByteBuffers` when writing to a new file.
    internal let allocator: ByteBufferAllocator
    
    
    /// Creates a new `LocalStorage` intance.
    ///
    /// - Parameters:
    ///   - worker: The event loop group that the service lives on.
    ///   - manager: The file manager used for checking for a files existance and other validation operations. Defaults to `.default`.
    ///   - defaultPath: The default path to store files to if no path is passed in. Defaults to `nil`.
    ///   - pool: The thread pool used to asyncronously write to files. Also used to initialize the `NonBlockingFileIO` instance.
    ///     Defaults to a thread pool with 2 threads.
    public init(
        eventLoop: EventLoop,
        manager: FileManager = .default,
        defaultPath path: String? = nil,
        pool: NIOThreadPool = NIOThreadPool(numberOfThreads: 2)
    ) {
        self.eventLoop = eventLoop
        self.manager = manager
        self.defaultPath = path

        self.threadPool = pool
        self.io = NonBlockingFileIO(threadPool: pool)
        self.allocator = ByteBufferAllocator()
        
        self.threadPool.start()
    }

    /// See `Storage.store(file:at:)`.
    public func store(file: File, at optionalPath: String? = nil) -> EventLoopFuture<String> {
        do {
            
            // Get the path that the file will be created at.
            let possibleUrl = (optionalPath ?? self.defaultPath).flatMap(URL.init(fileURLWithPath:))
            guard let containingUrl = possibleUrl else {
                throw StorageError(identifier: "pathRequired", reason: "A path is required to store files locally")
            }
            
            // Create the path of the file to create
            let name = containingUrl.appendingPathComponent(file.filename).path
            
            // Create a new file and a `FileHandle` instance from its descriptor.
            // The `O_EXCL` flag makes sure the file doesn't already exist.
            // The `O_CREAT` flag causes the file to be created since it doesn't exist.
            // The `O_TRUNC` flag removes any data from the file.
            // The `O_RDWR` flag opens the file to be either written or read.
            let fd = open(name, O_RDWR | O_TRUNC | O_CREAT | O_EXCL, S_IRWXU | S_IRGRP | S_IROTH)
            guard fd >= 0 else {
                throw StorageError(identifier: "errno", reason: "(\(errno))" + String(cString: strerror(errno)))
            }
            let handle = NIOFileHandle(descriptor: fd)
            
            // Stream the file data into the empty file.
            let write = self.io.write(fileHandle: handle, buffer: file.buffer, eventLoop: self.eventLoop)
            return write.always { _ in
                try? handle.close()
            }.map { name }
        } catch let error {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
    
    /// See `Storage.fetch(file:)`.
    public func fetch(file: String) -> EventLoopFuture<File> {
        do {
            // Make sure a file exists at the given path.
            try self.assert(path: file)
            
            // Get the name of the file. This is for the `File` instance that will be returned.
            guard let name = file.split(separator: "/").last.map(String.init) else {
                throw StorageError(identifier: "emptyPath", reason: "Cannot parse file name from an empty string.")
            }
            
            // Get the size of the file we will be reading.
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: file), let fileSize = attributes[.size] as? NSNumber else {
                throw StorageError(identifier: "fileSize", reason: "Could not determine file size of file `\(file)`.")
            }

            let handle = try NIOFileHandle(path: file)
            var fileData = Data()
            fileData.reserveCapacity(fileSize.intValue)
            
            // Stream the file data into the `fileData` variable.
            return self.io.readChunked(
                fileHandle: handle,
                byteCount: fileSize.intValue,
                chunkSize: NonBlockingFileIO.defaultChunkSize,
                allocator: self.allocator,
                eventLoop: self.eventLoop
            ) { chunk in
                chunk.withUnsafeReadableBytes { ptr in
                    fileData.append(ptr.bindMemory(to: UInt8.self))
                }
                
                return self.eventLoop.makeSucceededFuture(())
            }.map {
                var buffer = self.allocator.buffer(capacity: fileData.count)
                buffer.writeBytes(fileData)
                return File(buffer: buffer, filename: name)
            }.always { _ in
                try? handle.close()
            }
        } catch let error {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
    
    /// See `Storage.write(file:data:options:)`.
    public func write(file: String, with data: Data) -> EventLoopFuture<File> {
        do {
            // Make sure a file exists at the given path.
            try self.assert(path: file)
            
            // Write the new data to the file on the currenct event loop.
            let write = self.threadPool.runIfActive(eventLoop: self.eventLoop) {
                return try data.write(to: URL(fileURLWithPath: file), options: [])
            }
            
            // Read the updated file and return it.
            return write.flatMap { self.fetch(file: file) }
        } catch let error {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
    
    /// See `Storage.delete(file:)`.
    public func delete(file: String) -> EventLoopFuture<Void> {
        do {
            // Make sure a file exists at the given path.
            try self.assert(path: file)
            
            // Asynchronously
            return self.threadPool.runIfActive(eventLoop: self.eventLoop) {
                return try self.manager.removeItem(atPath: file)
            }
        } catch let error {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
    
    /// Verifies that a file exists at a given path.
    private func assert(path: String)throws {
        var isDirectory: ObjCBool = false
        guard self.manager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw StorageError(identifier: "noFile", reason: "Unable to find file at path `\(path)`")
        }
    }
}
