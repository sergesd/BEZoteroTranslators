// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BEZoteroTranslators",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BEZoteroTranslators",
            targets: ["BEZoteroTranslators"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BEZoteroTranslators",
            dependencies: [],
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "BEZoteroTranslatorsTests",
            dependencies: [
                "BEZoteroTranslators"
            ]),
    ]
) 
