import Vapor

/// A `Storage` implementation that handles local file storage.
///
/// ## Initializing
///
/// `LocalStorage` conforms to the `ServiceType` protocol, so you can simply register it with your services and access it from a container:
///
///     services.register(LocalStorage.self)
///     try container.make(LocalStorage.self)
///
/// There is also a public initializer you can use if you want to use it without a `Container` instance or customize some of its properties:
///
///     let storage = LocalStorage(worker: eventLoopGroup, manager: FileManager.default, defaultPath: nil, pool: BlockingIOThreadPool(numberOfThreads: 2))
///
/// Only the `worker` parameter is required. All others have a default value.
///
/// ## Creating New Files
///
/// The `LocalStorage.store(file:at:)` method creats a new file at a given path with the `file.data` value as its contents.
/// If the `LocalStorage.defaultPath` property is not `nil`, you can pass `nil` into the `path` parameter
/// and the file will be stored at the default path. If there is no `path` or `defaultPath`, the `StorageError.pathRequired` error will be thrown.
///
/// The path the file is stored at will be `path` + `file.name`. The `.store` method will handle forward slashes in the path.
///
///     storage.store(file: Fail(data: Data(), name: "README.md"), at: "/Users/hackerman/projects/AwesomeProject")
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
/// The `localStorage.delete(file:)` method deletes an existing file by running the `FileManager.deleteItem` method in the `BlockingIOThraedPool`.
///
///     storage.delete(file:  "/Users/hackerman/projects/AwesomeProject")
public struct LocalStorage: Storage, ServiceType {
    
    /// See `ServiceType.makeService(for:)`.
    public static func makeService(for worker: Container) throws -> LocalStorage {
        return try LocalStorage(worker: worker, pool: worker.make())
    }
    
    /// The event loop group that the service lives on.
    public let worker: Worker
    
    /// The default path to store files to if no path is passed in.
    public let defaultPath: String?
    
    
    /// The file manager used for checking for a files existance and other validation operations.
    internal let manager: FileManager
    
    /// The thread pool used to asynchronously write to files. Also used to initialize the `NonBlockingFileIO` instance.
    internal let threadPool: BlockingIOThreadPool
    
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
        worker: Worker,
        manager: FileManager = .default,
        defaultPath path: String? = nil,
        pool: BlockingIOThreadPool = BlockingIOThreadPool(numberOfThreads: 2)
    ) {
        self.worker = worker
        self.manager = manager
        self.defaultPath = path

        self.threadPool = pool
        self.io = NonBlockingFileIO(threadPool: pool)
        self.allocator = ByteBufferAllocator()
        
        self.threadPool.start()
    }
    
    /// See `Storage.store(file:at:)`.
    public func store(file: File, at optionalPath: String?) -> EventLoopFuture<String> {
        do {
            
            // Get the path that the file will be created at.
            let path: String
            if let unwrappedPath = optionalPath {
                path = unwrappedPath
            } else if let defaultPath = self.defaultPath {
                path = defaultPath
            } else {
                throw StorageError(identifier: "pathRequired", reason: "A path is required to store files locally")
            }
            
            // Create the path of the file to create, and make sure no file or directory already exists.
            let name = path.last == "/" ? path + file.filename : path + "/" + file.filename
            guard !self.manager.fileExists(atPath: name) else {
                throw StorageError(identifier: "fileExists", reason: "A file already exists at path `\(name)`")
            }
            
            // Create an empty file.
            self.manager.createFile(atPath: name, contents: nil, attributes: [:])
            
            // Create a `ByteBuffer` to stream the file data from.
            let handle = try FileHandle(path: name)
            var buffer = self.allocator.buffer(capacity: file.data.count)
            buffer.write(bytes: file.data)
            
            // Stream the file data into the empty file.
            return self.io.write(fileHandle: handle, buffer: buffer, eventLoop: self.worker.eventLoop).always {
                try? handle.close()
            }.transform(to: name)
        } catch let error {
            return self.worker.future(error: error)
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
            
            let handle = try FileHandle(path: file)
            var fileData = Data()
            fileData.reserveCapacity(fileSize.intValue)
            
            // Stream the file data into the `fileData` variable.
            return self.io.readChunked(
                fileHandle: handle,
                byteCount: fileSize.intValue,
                chunkSize: NonBlockingFileIO.defaultChunkSize,
                allocator: self.allocator,
                eventLoop: self.worker.eventLoop
            ) { chunk in
                chunk.withUnsafeReadableBytes { ptr in
                    fileData.append(ptr.bindMemory(to: UInt8.self))
                }
                
                return self.worker.future()
            }.map {
                
                // Return the file data (contents and name).
                return File(data: fileData, filename: name)
            }.always {
                try? handle.close()
            }
        } catch let error {
            return self.worker.future(error: error)
        }
    }
    
    /// See `Storage.write(file:data:options:)`.
    public func write(file: String, with data: Data, options: Data.WritingOptions) -> EventLoopFuture<File> {
        do {
            // Make sure a file exists at the given path.
            try self.assert(path: file)
            
            // Create the URL that the data will write to.
            guard let url = URL(string: "file://" + file) else {
                throw StorageError(identifier: "fileURL", reason: "Unable to create a file URL from path `\(file)`")
            }
            
            // Write the new data to the file on the currenct event loop.
            let write = self.threadPool.runIfActive(eventLoop: self.worker.eventLoop) {
                return try data.write(to: url, options: options)
            }
            
            // Read the updated file and return it.
            return write.flatMap { self.fetch(file: file) }
        } catch let error {
            return self.worker.future(error: error)
        }
    }
    
    /// See `Storage.delete(file:)`.
    public func delete(file: String) -> EventLoopFuture<Void> {
        do {
            // Make sure a file exists at the given path.
            try self.assert(path: file)
            
            // Asynchronously
            return self.threadPool.runIfActive(eventLoop: self.worker.eventLoop) {
                return try self.manager.removeItem(atPath: file)
            }
        } catch let error {
            return self.worker.future(error: error)
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
