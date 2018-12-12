// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "Storage",
    products: [
        .library(name: "Storage", targets: ["Storage"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Storage", dependencies: []),
        .testTarget(name: "StorageTests", dependencies: ["Storage"]),
    ]
)