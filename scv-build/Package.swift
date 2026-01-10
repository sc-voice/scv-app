// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "scv-build",
  platforms: [
    .macOS(.v15),
  ],
  dependencies: [
    .package(path: "../scv-core"),
  ],
  targets: [
    .target(
      name: "scvBuildLib",
      dependencies: [
        .product(name: "scvCore", package: "scv-core"),
      ],
      path: "Sources/scvBuild",
    ),
    .executableTarget(
      name: "scv-build",
      dependencies: [
        .target(name: "scvBuildLib"),
      ],
      path: "Sources/scvBuildCLI",
    ),
    .testTarget(
      name: "scvBuildTests",
      dependencies: [
        .target(name: "scvBuildLib"),
        .product(name: "scvCore", package: "scv-core"),
      ],
    ),
  ],
)
