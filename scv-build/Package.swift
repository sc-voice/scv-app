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
      name: "scv-build",
      dependencies: [
        .product(name: "scvCore", package: "scv-core"),
      ],
      path: "Sources/scvBuild",
    ),
    .executableTarget(
      name: "scv-build-cli",
      dependencies: [
        .target(name: "scv-build"),
      ],
      path: "Sources/scvBuildCLI",
    ),
    .executableTarget(
      name: "verify-manifest",
      dependencies: [
        .product(name: "scvCore", package: "scv-core"),
      ],
      path: "Sources/verify-manifest",
    ),
    .testTarget(
      name: "scvBuildTests",
      dependencies: [
        .target(name: "scv-build"),
        .product(name: "scvCore", package: "scv-core"),
      ],
    ),
  ],
)
