// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LangoTraceSpeech",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "LangoTraceSpeech",
            targets: ["LangoTraceSpeech"]
        ),
    ],
    dependencies: [
        .package(path: "../LangoTraceCore"),
    ],
    targets: [
        .target(
            name: "LangoTraceSpeech",
            dependencies: [
                .product(name: "LangoTraceCore", package: "LangoTraceCore"),
            ]
        ),
        .testTarget(
            name: "LangoTraceSpeechTests",
            dependencies: [
                "LangoTraceSpeech",
                .product(name: "LangoTraceCore", package: "LangoTraceCore"),
            ]
        ),
    ]
)
