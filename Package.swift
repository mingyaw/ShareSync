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
        .library(
            name: "ShareSyncNotes",
            targets: ["ShareSyncNotes"]
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
        .target(
            name: "ShareSyncNotes",
            path: "macos/ShareSyncNotes"
        ),
        .testTarget(
            name: "ShareSyncNotesTests",
            dependencies: ["ShareSyncNotes"],
            path: "Tests/ShareSyncNotesTests"
        ),
    ]
)
