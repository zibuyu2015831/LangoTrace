// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LangoTraceAI",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "LangoTraceAI",
            targets: ["LangoTraceAI"]
        ),
    ],
    dependencies: [
        .package(path: "../LangoTraceCore"),
    ],
    targets: [
        .target(
            name: "LangoTraceAI",
            dependencies: [
                .product(name: "LangoTraceCore", package: "LangoTraceCore"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "LangoTraceAITests",
            dependencies: ["LangoTraceAI"]
        ),
    ]
)
