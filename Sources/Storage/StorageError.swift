import Core

public struct StorageError: Debuggable {
    public var identifier: String
    public var reason: String
    
    public init(identifier: String, reason: String) {
        self.identifier = identifier
        self.reason = reason
    }
}
