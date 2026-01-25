// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "scv-tasks",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "scvTasks",
      targets: ["scvTasks"],
    ),
    .executable(
      name: "task",
      targets: ["CLI"],
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/mhayes853/swift-uuidv7.git",
      from: "0.1.0",
    ),
    .package(path: "../scv-core"),
  ],
  targets: [
    .target(
      name: "scvTasks",
      dependencies: [
        .product(name: "UUIDV7", package: "swift-uuidv7"),
      ],
      path: "Sources/scvTasks",
    ),
    .testTarget(
      name: "scvTasksTests",
      dependencies: [
        "scvTasks",
      ],
      path: "Tests",
    ),
    .executableTarget(
      name: "CLI",
      dependencies: [
        "scvTasks",
        .product(name: "UUIDV7", package: "swift-uuidv7"),
        .product(name: "scvCore", package: "scv-core"),
      ],
      path: "Sources/CLI",
    ),
  ],
)
