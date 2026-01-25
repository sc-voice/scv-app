import Foundation
import UUIDV7

public class TaskManager: @unchecked Sendable {
  public static let shared = TaskManager()

  private let tasksDirectory: URL
  private let stackFilePath: URL
  private let settingsFilePath: URL
  private let lock = NSLock()
  private var currentTask: Task?

  public init(basePath: URL? = nil) {
    let base = basePath ??
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    tasksDirectory = base.appendingPathComponent("Tasks", isDirectory: true)
    stackFilePath = base.appendingPathComponent("world.json")
    settingsFilePath = base.appendingPathComponent(".task-settings.json")

    createDirectoriesIfNeeded()
    loadCurrentTask()
  }

  private func createDirectoriesIfNeeded() {
    try? FileManager.default.createDirectory(
      at: tasksDirectory,
      withIntermediateDirectories: true,
      attributes: nil,
    )
  }

  public func save(_ task: Task) throws {
    let fileName = task.fileName + ".json"
    let fileURL = tasksDirectory.appendingPathComponent(fileName)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(task)
    try data.write(to: fileURL)
  }

  public func load(taskId: UUIDV7) throws -> Task {
    let task = Task(id: taskId, name: "", summary: "")
    let fileName = task.fileName + ".json"
    let fileURL = tasksDirectory.appendingPathComponent(fileName)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let data = try Data(contentsOf: fileURL)
    return try decoder.decode(Task.self, from: data)
  }

  public func setCurrentTask(_ task: Task) throws {
    defer { lock.unlock() }
    lock.lock()
    currentTask = task
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(task)
    try data.write(to: stackFilePath)
  }

  public func getCurrentTask() -> Task? {
    defer { lock.unlock() }
    lock.lock()
    return currentTask
  }

  public func clearCurrentTask() throws {
    defer { lock.unlock() }
    lock.lock()
    currentTask = nil
    try FileManager.default.removeItem(at: stackFilePath)
  }

  private func loadCurrentTask() {
    defer { lock.unlock() }
    lock.lock()

    guard FileManager.default.fileExists(atPath: stackFilePath.path) else {
      return
    }

    do {
      let data = try Data(contentsOf: stackFilePath)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      currentTask = try decoder.decode(Task.self, from: data)
    } catch {
      print("Failed to load current task: \(error)")
    }
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
