// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wonder",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Wonder", targets: ["Wonder"])
    ],
    targets: [
        .executableTarget(
            name: "Wonder",
            path: "Sources/GlassTranslate"
        ),
        .testTarget(
            name: "WonderTests",
            dependencies: ["Wonder"],
            path: "Tests/GlassTranslateTests"
        )
    ]
)
