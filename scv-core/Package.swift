// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "scv-core",
  platforms: [
    .iOS(.v18),
    .macOS(.v15)
  ],
  products: [
    .library(
      name: "scvCore",
      targets: ["scvCore"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "scvCore",
      dependencies: [],
      path: "Sources",
      resources: [.process("../Resources")]
    ),
    .testTarget(
      name: "scvCoreTests",
      dependencies: ["scvCore"],
      path: "Tests",
      resources: [.process("../Resources")]
    )
  ]
)
