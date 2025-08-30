import ProjectDescription

let dependencies = Dependencies(
    carthage: nil,
    swiftPackageManager: SwiftPackageManagerDependencies(
        packages: [
            .remote(
                url: "https://github.com/kishikawakatsumi/KeychainAccess",
                requirement: .upToNextMajor(from: "4.2.2")
            ),
            .remote(
                url: "https://github.com/apple/swift-log",
                requirement: .upToNextMajor(from: "1.5.3")
            ),
            .remote(
                url: "https://github.com/orlandos-nl/Citadel",
                requirement: .upToNextMajor(from: "0.7.0")
            )
        ],
        productTypes: [
            "KeychainAccess": .framework,
            "Logging": .framework,
            "Citadel": .framework
        ]
    ),
    platforms: [.iOS]
)