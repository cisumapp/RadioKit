// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RadioKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "RadioKit",
            targets: ["RadioKit"]
        ),
    ],
    targets: [
        .target(
            name: "RadioKit"
        ),
        .testTarget(
            name: "RadioKitTests",
            dependencies: ["RadioKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
