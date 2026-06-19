// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LangoTraceSync",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "LangoTraceSync",
            targets: ["LangoTraceSync"]
        ),
    ],
    dependencies: [
        .package(path: "../LangoTraceCore"),
    ],
    targets: [
        .target(
            name: "LangoTraceSync",
            dependencies: [
                .product(name: "LangoTraceCore", package: "LangoTraceCore"),
            ]
        ),
        .testTarget(
            name: "LangoTraceSyncTests",
            dependencies: [
                "LangoTraceSync",
            ]
        ),
    ]
)
