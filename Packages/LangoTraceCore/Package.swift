// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LangoTraceCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "LangoTraceCore",
            targets: ["LangoTraceCore"]
        ),
    ],
    targets: [
        .target(
            name: "LangoTraceCore"
        ),
        .testTarget(
            name: "LangoTraceCoreTests",
            dependencies: ["LangoTraceCore"]
        ),
    ]
)
