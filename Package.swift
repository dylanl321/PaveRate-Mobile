// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PaveRate",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "PaveRateCore", targets: ["PaveRateCore"])
    ],
    targets: [
        .target(name: "PaveRateCore"),
        .testTarget(
            name: "PaveRateCoreTests",
            dependencies: ["PaveRateCore"]
        )
    ]
)
