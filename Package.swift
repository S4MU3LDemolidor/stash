// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Stash",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Stash", targets: ["Stash"]),
    ],
    dependencies: [
        // 2.x needs Xcode (not just the Command Line Tools): it uses `#Preview`.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Stash",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/Stash"
        ),
        .testTarget(
            name: "StashTests",
            dependencies: ["Stash"],
            path: "Tests/StashTests"
        ),
    ]
)
