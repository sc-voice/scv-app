import Foundation
import scvBuildLib

@main
struct BuildCLI {
  static func main() {
    let projectRoot = ProcessInfo.processInfo.environment["PROJECT_ROOT"] ??
      FileManager.default.currentDirectoryPath
    let command = BuildDBCommand(projectRoot: projectRoot)
    do {
      try command.run()
    } catch {
      print("ERROR: \(error)")
      exit(1)
    }
  }
}
