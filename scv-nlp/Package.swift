// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "scv-nlp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "scvNLP",
            targets: ["scvNLP"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "scvNLP",
            dependencies: []
        ),
        .testTarget(
            name: "CoreMLTests",
            dependencies: ["scvNLP"]
        ),
    ]
)
