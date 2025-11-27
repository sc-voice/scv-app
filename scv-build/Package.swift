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
    .executableTarget(
      name: "scv-build",
      dependencies: [
        .product(name: "scvCore", package: "scv-core"),
      ],
      path: "Sources/scvBuild",
    ),
    .testTarget(
      name: "scvBuildTests",
      dependencies: [
        .product(name: "scvCore", package: "scv-core"),
      ],
    ),
  ],
)
