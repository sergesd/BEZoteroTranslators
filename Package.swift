// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "BEZoteroTranslators",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "BEZoteroTranslators",
            targets: ["BEZoteroTranslators"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BEZoteroTranslators",
            dependencies: [],
            resources: [
                .process("Resources/ZoteroJS")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "BEZoteroTranslatorsTests",
            dependencies: ["BEZoteroTranslators"]),
    ]
) 