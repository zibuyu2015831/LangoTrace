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
        .package(path: "../LangoTraceData"),
    ],
    targets: [
        .target(
            name: "LangoTraceUI",
            dependencies: [
                .product(name: "LangoTraceCore", package: "LangoTraceCore"),
                .product(name: "LangoTraceData", package: "LangoTraceData"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "LangoTraceUITests",
            dependencies: [
                "LangoTraceUI",
                .product(name: "LangoTraceData", package: "LangoTraceData"),
            ]
        ),
    ]
)
