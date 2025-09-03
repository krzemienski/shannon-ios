import ProjectDescription

public extension Settings {
    static func baseSettings() -> Settings {
        .settings(
            base: [
                // Architecture Settings
                "ARCHS": "$(ARCHS_STANDARD)",
                "VALID_ARCHS": "arm64 x86_64",
                "ONLY_ACTIVE_ARCH": "YES",
                
                // Deployment
                "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
                "TARGETED_DEVICE_FAMILY": "1,2",
                "SUPPORTS_MACCATALYST": "NO",
                "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
                "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
                
                // Swift Settings
                "SWIFT_VERSION": "6.0",
                "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_TREAT_WARNINGS_AS_ERRORS": "NO",
                "SWIFT_SUPPRESS_WARNINGS": "NO",
                "SWIFT_EMIT_LOC_STRINGS": "YES",
                
                // Code Signing - Use automatic development signing
                "DEVELOPMENT_TEAM": "",
                "CODE_SIGN_STYLE": "Automatic",
                "CODE_SIGN_IDENTITY": "Apple Development",
                
                // App Info
                "MARKETING_VERSION": "1.0.0",
                "CURRENT_PROJECT_VERSION": "1",
                "VERSIONING_SYSTEM": "apple-generic",
                
                // Build Settings
                "ENABLE_BITCODE": "NO",
                "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
                "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "YES",
                "CLANG_ENABLE_MODULES": "YES",
                "ENABLE_MODULE_VERIFIER": "YES",
                "MODULE_VERIFIER_SUPPORTED_LANGUAGES": "objective-c objective-c++",
                "MODULE_VERIFIER_SUPPORTED_LANGUAGE_STANDARDS": "gnu11 gnu++20",
                
                // Warnings
                "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
                "CLANG_WARN_BOOL_CONVERSION": "YES",
                "CLANG_WARN_COMMA": "YES",
                "CLANG_WARN_CONSTANT_CONVERSION": "YES",
                "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
                "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
                "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
                "CLANG_WARN_EMPTY_BODY": "YES",
                "CLANG_WARN_ENUM_CONVERSION": "YES",
                "CLANG_WARN_INFINITE_RECURSION": "YES",
                "CLANG_WARN_INT_CONVERSION": "YES",
                "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
                "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
                "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
                "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
                "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
                "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
                "CLANG_WARN_STRICT_PROTOTYPES": "YES",
                "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
                "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
                "CLANG_WARN_UNREACHABLE_CODE": "YES",
                "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
                "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
                "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
                "GCC_WARN_UNDECLARED_SELECTOR": "YES",
                "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
                "GCC_WARN_UNUSED_FUNCTION": "YES",
                "GCC_WARN_UNUSED_VARIABLE": "YES",
                
                // Localization
                "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES"
            ],
            configurations: [
                .debug(name: .debug, settings: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"
                ], xcconfig: .relativeToRoot("Configs/Debug.xcconfig")),
                .release(name: .release, settings: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "RELEASE"
                ], xcconfig: .relativeToRoot("Configs/Release.xcconfig"))
            ]
        )
    }
    
    static func appSettings() -> Settings {
        .settings(
            base: [
                // Bundle Settings
                "PRODUCT_BUNDLE_IDENTIFIER": "com.claudecode.ios",
                "PRODUCT_NAME": "ClaudeCode",
                "EXECUTABLE_NAME": "ClaudeCode",
                "INFOPLIST_FILE": "Resources/Info.plist",
                "INFOPLIST_OUTPUT_FORMAT": "xml",
                "INFOPLIST_PREPROCESS": "NO",
                
                // Entitlements
                "CODE_SIGN_ENTITLEMENTS": "ClaudeCode.entitlements",
                
                // Code signing for development
                "CODE_SIGNING_REQUIRED": "YES",
                "CODE_SIGNING_ALLOWED": "YES",
                
                // UI Settings
                "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
                "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
                "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
                "INFOPLIST_KEY_UIStatusBarStyle": "UIStatusBarStyleLightContent",
                "INFOPLIST_KEY_UIUserInterfaceStyle": "Dark",
                "INFOPLIST_KEY_UIRequiresFullScreen": "NO",
                "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
                "INFOPLIST_KEY_UISupportedInterfaceOrientations~ipad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
                
                // App Information
                "INFOPLIST_KEY_CFBundleDisplayName": "Claude Code",
                "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.developer-tools",
                "INFOPLIST_KEY_NSHumanReadableCopyright": "© 2024 Claude Code",
                
                // Development
                "ENABLE_PREVIEWS": "YES",
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor"
            ],
            configurations: [
                .debug(name: .debug, settings: [
                    // Debug-specific settings
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                    "ENABLE_TESTABILITY": "YES",
                    "GCC_OPTIMIZATION_LEVEL": "0",
                    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
                    
                    // For simulator, allow automatic signing to work
                    "CODE_SIGNING_REQUIRED[sdk=iphonesimulator*]": "NO",
                    "CODE_SIGN_IDENTITY[sdk=iphonesimulator*]": "-",
                    
                    // For device, use development signing
                    "CODE_SIGNING_REQUIRED[sdk=iphoneos*]": "YES",
                    "CODE_SIGN_IDENTITY[sdk=iphoneos*]": "Apple Development"
                ]),
                .release(name: .release, settings: [
                    // Release-specific settings
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "RELEASE",
                    "ENABLE_TESTABILITY": "NO",
                    "GCC_OPTIMIZATION_LEVEL": "s",
                    "SWIFT_OPTIMIZATION_LEVEL": "-O",
                    
                    // Release builds require proper signing
                    "CODE_SIGNING_REQUIRED": "YES",
                    "CODE_SIGN_IDENTITY": "Apple Development"
                ])
            ]
        )
    }
}