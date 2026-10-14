// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Stash",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Stash", targets: ["Stash"]),
    ],
    dependencies: [
        // Pinned: 2.x uses `#Preview`, which needs Xcode's macro plugins and fails to
        // build with the Command Line Tools alone. Revisit once Xcode is the baseline.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.15.0"),
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
    ]
)
