import Foundation
import PackagePlugin

@main
struct GenerateManifestPlugin: BuildToolPlugin {
  @available(*, deprecated, message: "Uses PackagePlugin Path API - URL API not yet available for inputFiles/outputFiles parameters")
  func createBuildCommands(context: PluginContext, target: Target) async throws
    -> [Command]
  {
    // Only run for scvCore target
    guard target.name == "scvCore" else { return [] }

    guard let sourceTarget = target as? SourceModuleTarget else { return [] }

    let inputPath = sourceTarget.directory
      .appending("Resources")
      .appending("db-manifest.json")
    let outputPath = context.pluginWorkDirectory
      .appending("ManifestGenerated.swift")

    // Note: Path.string is deprecated in favor of URL, but the Swift Package
    // Plugin API requires Path types, so we must use .string conversions here.
    // Warnings are unavoidable until PackagePlugin API is updated to support URL.
    return try [
      .buildCommand(
        displayName: "Generate Manifest Swift Code",
        executable: context.tool(named: "generate-manifest").path,
        arguments: [
          inputPath.string,
          outputPath.string,
        ],
        inputFiles: [inputPath],
        outputFiles: [outputPath],
      ),
    ]
  }
}
