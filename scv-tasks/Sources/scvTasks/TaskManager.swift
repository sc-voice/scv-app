import Foundation
import UUIDV7

public class TaskManager: @unchecked Sendable {
  public static let shared = TaskManager()

  private let tasksDirectory: URL

  public init(basePath: URL? = nil) {
    let base = basePath ??
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    tasksDirectory = base.appendingPathComponent("Tasks", isDirectory: true)

    createDirectoriesIfNeeded()
  }

  private func createDirectoriesIfNeeded() {
    try? FileManager.default.createDirectory(
      at: tasksDirectory,
      withIntermediateDirectories: true,
      attributes: nil,
    )
  }

  public func save(_ task: Task) throws {
    let fileName = task.idFile + ".json"
    let fileURL = tasksDirectory.appendingPathComponent(fileName)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(task)
    try data.write(to: fileURL)
  }

  public func load(taskId: UUIDV7) throws -> Task {
    let idFile = Task.uuidToFilename(taskId)
    let fileName = idFile + ".json"
    let fileURL = tasksDirectory.appendingPathComponent(fileName)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let data = try Data(contentsOf: fileURL)
    return try decoder.decode(Task.self, from: data)
  }

  public func allTasks() throws -> [Task] {
    let files = try FileManager.default.contentsOfDirectory(
      at: tasksDirectory,
      includingPropertiesForKeys: nil,
    ).filter { $0.pathExtension == "json" }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    return try files.compactMap { fileURL in
      let data = try Data(contentsOf: fileURL)
      return try decoder.decode(Task.self, from: data)
    }
  }
}
