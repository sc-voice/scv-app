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
        .copy("../Resources/en.lproj"),
        .copy("../Resources/pt-PT.lproj"),
        .copy("../Resources/fr.lproj"),
        .copy("../Resources/de.lproj"),
        .copy("../Resources/ebt-en-sujato.db"),
        .copy("../Resources/ebt-de-sabbamitta.db"),
        .copy("../Resources/ebt-de-sabbamitta.db.zst"),
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
        .copy("../Resources/en.lproj"),
        .copy("../Resources/pt-PT.lproj"),
        .copy("../Resources/de.lproj"),
        .copy("../Resources/fr.lproj"),
        .copy("../Resources/ebt-de-sabbamitta.db"),
        .copy("../Resources/ebt-de-sabbamitta.db.zst"),
        .copy("../Resources/ebt-fr-noeismet.db"),
        .copy("../Resources/ebt-fr-noeismet.db.zst"),
        .copy("Data/root-of-suffering.json"),
        .copy("Data/root-of-suffering-raw.json"),
      ],
    ),
  ],
)
