# Storage

Storage is a generic interface for resource storing APIs, such as Google Cloud Storage, Amazon S3, or your local file system.

## Installing

Add a package instance to your manifest's `dependencies` array with the [latest version](https://github.com/skelpo/Storage/releases/latest):

```swift
.package(url: "https://github.com/skelpo/Storage.git", from: "0.1.0")
```

Then run `swift package update` and regenerate your Xcode project if you have one.

## API

### `Storage`

The Storage package is built around the `Storage` protocol which defines a type that can create, read, update, and delete files.

It requires 4 methods:

- `func store(file: File, at path: String?) -> EventLoopFuture<String>`
- `func fetch(file: String) -> EventLoopFuture<File>`
- `func write(file: String, with data: Data) -> EventLoopFuture<File>`
- `func delete(file: String) -> EventLoopFuture<Void>`


### `StorageError`

If any error occurs in the `Storage` methods, a `StorageError` is returned in the future. Use this error if you create your own `Storage` implementation.

### `LocalStorage`

A `Storage` implementation for interacting with files in your local file system. The `store` and `fetch` methods stream the file data, while the `delete` and `write` methods are run on the instance's event loop.

`LocalStorage` conforms to `ServiceType`, so you can register it with the rest of your app's services.

## Documentation

You can see the API documentation [here](http://www.skelpo.codes/Storage).

## License

This package is registered under the [MIT license agreement](https://github.com/skelpo/Storage/blob/master/LICENSE).
