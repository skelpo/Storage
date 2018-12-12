import Vapor

public struct LocalStorage: Storage, ServiceType {
    public static func makeService(for worker: Container) throws -> LocalStorage {
        return LocalStorage(worker: worker)
    }
    
    public let worker: Worker
    public let manager: FileManager
    public let defaultPath: String?
    
    public init(worker: Worker, manager: FileManager = .default, defaultPath path: String? = nil) {
        self.worker = worker
        self.manager = manager
        self.defaultPath = path
    }
    
    public func store(file: File, at optionalPath: String?) -> EventLoopFuture<String> {
        let path: String
        if let unwrappedPath = optionalPath {
            path = unwrappedPath
        } else if let defaultPath = self.defaultPath {
            path = defaultPath
        } else {
            return self.worker.future(error: StorageError(identifier: "pathRequired", reason: "A path is required to store files locally"))
        }
        
        let name = path.last == "/" ? path + file.filename : path + "/" + file.filename
        guard !self.manager.fileExists(atPath: name) else {
            return self.worker.future(error: StorageError(identifier: "fileExists", reason: "A file already exists at path `\(name)`"))
        }
        
        self.manager.createFile(atPath: name, contents: file.data, attributes: [:])
        
        return self.worker.future(name)
    }
    
    public func fetch(file: String) -> EventLoopFuture<File> {
        var isDirectory: ObjCBool = false
        guard self.manager.fileExists(atPath: file, isDirectory: &isDirectory) else {
            return self.worker.future(error: StorageError(identifier: "noFile", reason: "Unable to find file at path `\(file)`"))
        }
        
        guard let name = file.split(separator: "/").last.map(String.init) else {
            return self.worker.future(error: StorageError(identifier: "emptyPath", reason: "Cannot parse file name from an empty string."))
        }
        let data = self.manager.contents(atPath: file) ?? Data()
        
        return self.worker.future(File(data: data, filename: name))
    }
}
