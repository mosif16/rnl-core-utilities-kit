// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CoreUtilitiesKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CoreUtilitiesKit",
            targets: ["CoreUtilitiesKit"]
        )
    ],
    targets: [
        .target(
            name: "CoreUtilitiesKit"
        ),
        .testTarget(
            name: "CoreUtilitiesKitTests",
            dependencies: ["CoreUtilitiesKit"]
        )
    ]
)
