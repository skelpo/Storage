import Vapor

public protocol Storage {
    func store(file: File) -> Future<String>
    func fetch(file: String) -> Future<File>
}
