// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "GenerateManifestPlugin",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .plugin(
      name: "GenerateManifestPlugin",
      targets: ["GenerateManifestPlugin"],
    ),
  ],
  targets: [
    .executableTarget(
      name: "generate-manifest",
      path: "Sources/GenerateManifestExecutable",
    ),
    .plugin(
      name: "GenerateManifestPlugin",
      capability: .buildTool(),
      dependencies: ["generate-manifest"],
      path: "Sources/GenerateManifestPlugin",
    ),
  ],
)
