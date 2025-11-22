// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "scv-core",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "scvCore",
      targets: ["scvCore"],
    ),
  ],
  dependencies: [
    .package(path: "../scv-macros"),
    .package(url: "https://github.com/facebook/zstd.git", from: "1.5.5"),
  ],
  targets: [
    .target(
      name: "scvCore",
      dependencies: [
        .product(name: "scvMacros", package: "scv-macros"),
        .product(name: "libzstd", package: "zstd"),
      ],
      path: "Sources",
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .unsafeFlags(["-suppress-warnings"], .when(configuration: .debug)),
      ],
    ),
    .testTarget(
      name: "scvCoreTests",
      dependencies: [
        "scvCore",
        .product(name: "libzstd", package: "zstd"),
      ],
      path: "Tests",
      resources: [
        .process("../Sources/Resources"),
        .process("Data"),
      ],
    ),
  ],
)
