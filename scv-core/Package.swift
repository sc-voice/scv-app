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
        .process("../Resources/en.lproj"),
        .process("../Resources/pt-PT.lproj"),
        .process("../Resources/fr.lproj"),
        .process("../Resources/de.lproj"),
        .process("../Resources/ebt-en-sujato.db.zst"),
        .process("../Resources/ebt-de-sabbamitta.db.zst"),
        .process("../Resources/ebt-fr-noeismet.db.zst"),
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
        .process("../Resources/en.lproj"),
        .process("../Resources/pt-PT.lproj"),
        .process("../Resources/de.lproj"),
        .process("../Resources/fr.lproj"),
        .process("../Resources/ebt-en-sujato.db.zst"),
        .process("../Resources/ebt-de-sabbamitta.db.zst"),
        .process("../Resources/ebt-fr-noeismet.db.zst"),
        .process("Data/root-of-suffering.json"),
        .process("Data/root-of-suffering-raw.json"),
      ],
    ),
  ],
)
