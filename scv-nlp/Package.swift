// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "scv-nlp",
  platforms: [
    .iOS(.v17),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "scvNLP",
      targets: ["scvNLP"],
    ),
  ],
  dependencies: [
    .package(path: "../scv-core"),
  ],
  targets: [
    .target(
      name: "scvNLP",
      dependencies: [],
    ),
    .testTarget(
      name: "CoreMLTests",
      dependencies: ["scvNLP", .product(name: "scvCore", package: "scv-core")],
    ),
  ],
)
