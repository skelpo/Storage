import Foundation
import NIO

/// Represents a single file.
public struct File: Codable, Equatable {

    /// The name of the file, including the extension.
    ///
    ///     "README.md"
    public var filename: String

    /// The file's data stored as a `ByteBuffer`.
    public var buffer: ByteBuffer

    /// The file extension, if it has one.
    public var `extension`: String? {
        let parts = self.filename.split(separator: ".")
        if parts.count > 1 {
            return parts.last.map(String.init)
        } else {
            return nil
        }
    }

    /// The readable data contained in the `buffer` property.
    public var data: Data {
        guard let bytes = self.buffer.getBytes(
            at: self.buffer.readerIndex,
            length: self.buffer.readableBytes
        ) else {
            return Data()
        }

        return Data(bytes)
    }

    enum CodingKeys: String, CodingKey {
        case data, filename
    }

    /// `Decodable` conformance.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .data)
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        buffer.writeBytes(data)
        let filename = try container.decode(String.self, forKey: .filename)
        self.init(buffer: buffer, filename: filename)
    }

    /// `Encodable` conformance.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.data, forKey: .data)
        try container.encode(self.filename, forKey: .filename)
    }

    /// Creates a new `File`.
    ///
    ///     let file = File(data: Data("hello".utf8), filename: "foo.txt")
    ///
    /// - parameters:
    ///     - data: The file's contents as `Data`.
    ///     - filename: The name of the file, not including the path.
    public init(data: Data, filename: String) {
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        self.init(buffer: buffer, filename: filename)
    }

    /// Creates a new `File`.
    ///
    ///     let data = Data("hello".utf8)
    ///     var buffer = ByteBufferAllocator().buffer(capacity: data.count)
    ///     buffer.writeBytes(data)
    ///
    ///     let file = File(buffer: buffer, filename: "foo.txt")
    ///
    /// - parameters:
    ///     - buffer: The byte buffer containing the file's contents.
    ///     - filename: The name of the file, not including the path.
    public init(buffer: ByteBuffer, filename: String) {
        self.buffer = buffer
        self.filename = filename
    }
}
