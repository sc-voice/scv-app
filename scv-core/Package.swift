// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "scv-core",
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
  ],
  targets: [
    .target(
      name: "scvCore",
      dependencies: [
        .product(name: "scvMacros", package: "scv-macros"),
      ],
      path: "Sources",
      resources: [
        .copy("../Resources/en.lproj"),
        .copy("../Resources/pt-PT.lproj"),
        .copy("../Resources/fr.lproj"),
        .copy("../Resources/de.lproj"),
        .copy("../Resources/ebt-en-sujato.db"),
        .copy("../Resources/ebt-de-sabbamitta.db"),
      ],
    ),
    .testTarget(
      name: "scvCoreTests",
      dependencies: ["scvCore"],
      path: "Tests",
      resources: [
        .copy("../Resources/en.lproj"),
        .copy("../Resources/pt-PT.lproj"),
        .copy("../Resources/de.lproj"),
        .copy("../Resources/fr.lproj"),
        .copy("Data/root-of-suffering.json"),
        .copy("Data/root-of-suffering-raw.json"),
      ],
    ),
  ],
)
