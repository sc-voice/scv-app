// swift-tools-version:6.1
import PackageDescription

let package = Package(
  name: "scv-macros",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "scvMacros",
      targets: ["scvMacros"],
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
  ],
  targets: [
    .target(
      name: "scvMacros",
      dependencies: [],
      path: "Sources",
    ),
    .executableTarget(
      name: "scvMacrosPlugin",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      path: "Plugin/scvMacrosPlugin",
    ),
    .testTarget(
      name: "scvMacrosTests",
      dependencies: ["scvMacros"],
      path: "Tests",
    ),
  ],
)
