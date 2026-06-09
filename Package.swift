// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Runtahio",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "Runtahio", targets: ["Runtahio"]),
        .library(name: "RuntahioCore", targets: ["RuntahioCore"]),
    ],
    targets: [
        // Pure, testable business logic. No SwiftUI, no @main.
        .target(
            name: "RuntahioCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // The executable: @main SwiftUI App + views + AppKit/QuickLook interop.
        .executableTarget(
            name: "Runtahio",
            dependencies: ["RuntahioCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "RuntahioCoreTests",
            dependencies: ["RuntahioCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
