// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "scv-ui",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "scvUI",
            targets: ["scvUI"]
        ),
        .executable(
            name: "mock-response-view",
            targets: ["MockResponseView"]
        ),
    ],
    dependencies: [
        .package(path: "../scv-core"),
    ],
    targets: [
        .target(
            name: "scvUI",
            dependencies: [
                .product(name: "scvCore", package: "scv-core"),
            ]
        ),
        .testTarget(
            name: "scvUITests",
            dependencies: ["scvUI"]
        ),
        .executableTarget(
            name: "MockResponseView",
            dependencies: ["scvUI"]
        ),
    ]
)
