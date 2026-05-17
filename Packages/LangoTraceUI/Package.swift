// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LangoTraceUI",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "LangoTraceUI",
            targets: ["LangoTraceUI"]
        ),
    ],
    dependencies: [
        .package(path: "../LangoTraceCore"),
    ],
    targets: [
        .target(
            name: "LangoTraceUI",
            dependencies: [
                .product(name: "LangoTraceCore", package: "LangoTraceCore"),
            ]
        ),
        .testTarget(
            name: "LangoTraceUITests",
            dependencies: ["LangoTraceUI"]
        ),
    ]
)
