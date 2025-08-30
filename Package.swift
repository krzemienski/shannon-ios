// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeCodeSwift",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "ClaudeCodeSwift",
            targets: ["ClaudeCodeSwift"]
        )
    ],
    dependencies: [
        // Dependency Injection
        .package(
            url: "https://github.com/Swinject/Swinject",
            from: "2.9.0"
        ),
        // Security & Keychain
        .package(
            url: "https://github.com/kishikawakatsumi/KeychainAccess",
            from: "4.2.2"
        ),
        // Logging
        .package(
            url: "https://github.com/apple/swift-log",
            from: "1.5.3"
        ),
        // SSH Support
        .package(
            url: "https://github.com/orlandos-nl/Citadel",
            from: "0.7.0"
        )
    ],
    targets: [
        .target(
            name: "ClaudeCodeSwift",
            dependencies: [
                "Swinject",
                "KeychainAccess",
                .product(name: "Logging", package: "swift-log"),
                "Citadel"
            ],
            path: "Sources"
        )
    ]
)