import Vapor

/// A type that can store and fetch resources using an underlying API, such as Google Cloud Storage of Foundation's `FileManager`.
public protocol Storage {
    
    /// Stores a new file at a given path.
    ///
    /// - Parameters:
    ///   - file: The file data (name and contents) to store.
    ///   - path: The path to store the file at.
    ///
    ///     Some implementations will require a value for this paramter, such as `FileManager`. Others will never need it, like BackBlaze B2.
    ///
    /// - Returns: The full path to the file, including its name and extension.
    func store(file: File, at path: String?) -> EventLoopFuture<String>
    
    /// Gets file data from a path or URL.
    ///
    /// - Parameter file: The path or URL for the file's location.
    ///
    /// - Returns: The file's data (name and contents), wrapped in a future.
    func fetch(file: String) -> EventLoopFuture<File>
}
