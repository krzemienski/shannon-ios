import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "ClaudeCodeSwift",
    organizationName: "Claude Code Swift",
    options: .options(
        automaticSchemesOptions: .disabled,
        developmentRegion: "en",
        textSettings: .textSettings(
            usesTabs: false,
            indentWidth: 4,
            tabWidth: 4,
            wrapsLines: true
        )
    ),
    packages: [
        .remote(
            url: "https://github.com/Swinject/Swinject",
            requirement: .upToNextMajor(from: "2.9.0")
        ),
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
    settings: .baseSettings(),
    targets: [
        // Main App Target
        .target(
            name: "ClaudeCodeSwift",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "com.claudecodeswift.ios",
            deploymentTargets: .iOS("18.4"),
            infoPlist: .file(path: "Resources/Info.plist"),
            sources: [
                "Sources/**"
            ],
            resources: [
                .glob(pattern: "Resources/**", excluding: ["Resources/Info.plist"]),
                "ClaudeCodeSwift.xcdatamodeld"
            ],
            scripts: [
                .pre(
                    script: """
                    # SwiftLint check with proper configuration
                    if which swiftlint >/dev/null; then
                      echo "Running SwiftLint..."
                      swiftlint --config "${PROJECT_DIR}/.swiftlint.yml" --quiet || true
                    else
                      echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
                    fi
                    """,
                    name: "SwiftLint",
                    basedOnDependencyAnalysis: false
                ),
                .pre(
                    script: """
                    echo "Building ${PRODUCT_NAME} v${MARKETING_VERSION} (${CURRENT_PROJECT_VERSION})"
                    echo "Configuration: ${CONFIGURATION}"
                    echo "SDK: ${SDK_NAME}"
                    echo "Destination: ${PLATFORM_NAME}"
                    """,
                    name: "Build Info",
                    basedOnDependencyAnalysis: false
                ),
                .post(
                    script: """
                    echo "✅ Build completed successfully!"
                    echo "Product: ${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
                    echo "Configuration: ${CONFIGURATION}"
                    echo "Architecture: ${ARCHS}"
                    """,
                    name: "Build Notification",
                    basedOnDependencyAnalysis: false
                )
            ],
            dependencies: [
                .package(product: "Swinject"),
                .package(product: "KeychainAccess"),
                .package(product: "Logging"),
                .package(product: "Citadel")
            ],
            settings: .appSettings()
        ),
        
        // UI Tests Target
        .target(
            name: "ClaudeCodeUITests",
            destinations: [.iPhone, .iPad],
            product: .uiTests,
            bundleId: "com.claudecodeswift.ios.uitests",
            deploymentTargets: .iOS("18.4"),
            infoPlist: .default,
            sources: ["UITests/**"],
            dependencies: [
                .target(name: "ClaudeCodeSwift")
            ],
            settings: .settings(
                base: [
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.claudecodeswift.ios.uitests",
                    "GENERATE_INFOPLIST_FILE": "YES",
                    "TEST_TARGET_NAME": "ClaudeCodeSwift",
                    "SWIFT_EMIT_LOC_STRINGS": "NO"
                ],
                configurations: [
                    .debug(name: .debug, settings: [
                        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"
                    ]),
                    .release(name: .release, settings: [
                        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "RELEASE"
                    ])
                ]
            )
        )
    ],
    schemes: [
        .scheme(
            name: "ClaudeCodeSwift",
            shared: true,
            buildAction: .buildAction(
                targets: ["ClaudeCodeSwift"]
            ),
            runAction: .runAction(
                configuration: .debug,
                executable: "ClaudeCodeSwift"
            ),
            archiveAction: .archiveAction(
                configuration: .release
            ),
            profileAction: .profileAction(
                configuration: .release,
                executable: "ClaudeCodeSwift"
            ),
            analyzeAction: .analyzeAction(configuration: .debug)
        )
    ],
    resourceSynthesizers: [
        .assets(),
        .strings()
    ]
)