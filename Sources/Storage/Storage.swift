import Vapor

public protocol Storage {
    func store(file: File, at path: String?) -> Future<String>
    func fetch(file: String) -> Future<File>
}
