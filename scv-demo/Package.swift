// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ScvDemo",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../scv-ui")
    ],
    targets: [
        .executableTarget(
            name: "ScvDemo",
            dependencies: [
                .product(name: "scvUI", package: "scv-ui")
            ],
            path: "Sources/ScvDemo"
        )
    ]
)
