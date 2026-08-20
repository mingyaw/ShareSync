// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ShareSync",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "ShareSync",
            targets: ["ShareSync"]
        ),
    ],
    targets: [
        .target(
            name: "ShareSync",
            path: "ios/ShareSync"
        ),
        .testTarget(
            name: "ShareSyncTests",
            dependencies: ["ShareSync"],
            path: "Tests/ShareSyncTests"
        ),
    ]
)
