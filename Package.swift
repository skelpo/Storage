// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Storage",
    products: [
        .library(name: "Storage", targets: ["Storage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0")
    ],
    targets: [
        .target(name: "Storage", dependencies: ["NIO"]),
        .testTarget(name: "StorageTests", dependencies: ["Storage"]),
    ]
)
