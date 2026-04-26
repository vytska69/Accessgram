// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Accessgram",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Accessgram", targets: ["Accessgram"])
    ],
    targets: [
        .systemLibrary(
            name: "CTDLib",
            path: "Sources/CTDLib",
            pkgConfig: "tdjson",
            providers: [.brew(["tdlib"])]
        ),
        .executableTarget(
            name: "Accessgram",
            dependencies: ["CTDLib"],
            path: "Sources/Accessgram",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AccessgramTests",
            dependencies: ["Accessgram"],
            path: "Tests/AccessgramTests"
        )
    ]
)
