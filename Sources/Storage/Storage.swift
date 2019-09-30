import Foundation
import NIO

/// A type that can store and fetch resources using an underlying API, such as Google Cloud Storage or Foundation's `FileManager`.
public protocol Storage {
    
    /// Stores a new file at a given path.
    ///
    /// - Parameters:
    ///   - file: The file data (name and contents) to store.
    ///   - path: The path to store the file at.
    ///
    ///     Some implementations will require a value for this paramter, such as `FileManager`. Others will never need it, like BackBlaze B2.
    ///
    /// - Returns: The full path to the file, including its name and extension, wrapped in a future.
    func store(file: File, at path: String?) -> EventLoopFuture<String>
    
    /// Gets file data from a path or URL.
    ///
    /// - Parameter file: The path or URL for the file's location.
    ///
    /// - Returns: The file's data (name and contents), wrapped in a future.
    func fetch(file: String) -> EventLoopFuture<File>
    
    /// Writes new data to a file.
    ///
    /// - Parameters:
    ///   - file: The path or URL of the file to write to.
    ///   - data: The new data to write to the file.
    ///
    /// - Returns: The updated file information, wrapped in a future.
    func write(file: String, with data: Data) -> EventLoopFuture<File>
    
    /// Deletes a file.
    ///
    /// - Parameter file: The path or URL of the file to delete.
    ///
    /// - Returns: A void future that succeedes when the file is deleted.
    func delete(file: String) -> EventLoopFuture<Void>
}
