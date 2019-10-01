/// The error type that is thrown when a storage operation fails.
public struct StorageError: Error {
    
    /// A unique, machine readable, identifier for this error.
    public var identifier: String
    
    /// A human readable message that describes the reason for the error.
    public var reason: String
    
    /// Creates a new `StorageError` instance.
    ///
    /// - Parameters:
    ///   - identifier: A unique identifier for this error.
    ///   - reason: A message that describes the reason for the error.
    public init(identifier: String, reason: String) {
        self.identifier = identifier
        self.reason = reason
    }
}
