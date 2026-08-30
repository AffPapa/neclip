// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NeClip",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")
    ],
    targets: [
        .executableTarget(
            name: "NeClip",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/NeClip"
        ),
        .testTarget(
            name: "NeClipTests",
            dependencies: [
                "NeClip",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Tests/NeClipTests"
        )
    ]
)
