// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Runtahio",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "Runtahio", targets: ["Runtahio"]),
        .executable(name: "RuntahioBench", targets: ["RuntahioBench"]),
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
            // The iconset under Resources/ is consumed by Scripts/make-app.sh (iconutil),
            // not bundled by SPM, so exclude it from the target's source scan.
            exclude: ["Resources"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Headless benchmark harness over RuntahioCore (no SwiftUI). See Scripts/benchmark.sh.
        .executableTarget(
            name: "RuntahioBench",
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
