// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "reswift-effect",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "ReSwiftEffect",
            targets: ["ReSwiftEffect"]
        ),
    ],
    targets: [
        .target(
            name: "ReSwiftEffect",
        ),
        .testTarget(
            name: "ReSwift-EffectTests",
            dependencies: ["ReSwiftEffect"]
        ),
    ]
)
