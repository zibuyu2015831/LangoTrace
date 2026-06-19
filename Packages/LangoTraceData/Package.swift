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
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "LangoTraceData",
            dependencies: [
                .product(name: "LangoTraceCore", package: "LangoTraceCore"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "LangoTraceDataTests",
            dependencies: [
                "LangoTraceData",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
    ]
)
