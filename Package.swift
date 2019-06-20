// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Storage",
    products: [
        .library(name: "Storage", targets: ["Storage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-alpha")
    ],
    targets: [
        .target(name: "Storage", dependencies: ["Vapor"]),
        .testTarget(name: "StorageTests", dependencies: ["Storage"]),
    ]
)
