// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LangoTraceLearnerModel",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "LangoTraceLearnerModel",
            targets: ["LangoTraceLearnerModel"]
        ),
    ],
    dependencies: [
        .package(path: "../LangoTraceCore"),
        .package(path: "../LangoTraceData"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "LangoTraceLearnerModel",
            dependencies: [
                .product(name: "LangoTraceCore", package: "LangoTraceCore"),
                .product(name: "LangoTraceData", package: "LangoTraceData"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "LangoTraceLearnerModelTests",
            dependencies: [
                "LangoTraceLearnerModel",
                .product(name: "LangoTraceData", package: "LangoTraceData"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
    ]
)
