// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LangoTraceData",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "LangoTraceData",
            targets: ["LangoTraceData"]
        ),
    ],
    dependencies: [
        .package(path: "../LangoTraceCore"),
    ],
    targets: [
        .target(
            name: "LangoTraceData",
            dependencies: [
                .product(name: "LangoTraceCore", package: "LangoTraceCore"),
            ]
        ),
    ]
)
