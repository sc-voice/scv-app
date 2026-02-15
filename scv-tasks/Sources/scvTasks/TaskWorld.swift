import Foundation
import UUIDV7

/// TaskWorld implements ITaskWorld as the single API entry point for task
/// management.
/// All mutations are atomic and durable (persisted to disk immediately).
///
/// **Thread Safety**: TaskWorld is designed for single-threaded use (e.g.,
/// task_cli).
/// Marked `@unchecked Sendable` for Swift concurrency compatibility.
/// In the future, if multi-threaded access is needed, add locks to mutable
/// state
/// (taskMap, _taskStack) without changing the public API.
public class TaskWorld: ITaskWorld, @unchecked Sendable {
  public static let TEST_DEFAULT = "update unit tests"

  private var taskMap: [String: Task] = [:] // keyed by filename or UUID string
  private var worldModel: WorldModel
  private var basePath: URL
  private var taskManager: TaskManager
  private var worldFilePath: URL

  public var limit: Int {
    get { worldModel.limit }
    set { worldModel.limit = newValue }
  }

  public var verbosity: Int {
    get { worldModel.verbosity }
    set { worldModel.verbosity = newValue }
  }

  public var lineLength: Int {
    get { worldModel.lineLength }
    set { worldModel.lineLength = newValue }
  }

  public var showDone: Bool {
    get { worldModel.showDone }
    set { worldModel.showDone = newValue }
  }

  public var showUpdate: Bool {
    get { worldModel.showUpdate }
    set { worldModel.showUpdate = newValue }
  }

  public var testDefault: String {
    get { worldModel.testDefault }
    set { worldModel.testDefault = newValue }
  }

  public init(basePath: URL? = nil) {
    let path = basePath ?? Self.findProjectRoot()
    self.basePath = path
    taskManager = TaskManager(basePath: path)
    worldFilePath = path.appendingPathComponent(".task-world.json")

    // Load world model (stack + preferences)
    if FileManager.default.fileExists(atPath: worldFilePath.path) {
      do {
        worldModel = try WorldModel.load(from: worldFilePath)
      } catch {
        print(
          "Warning: Failed to load world model: \(error). Starting with defaults.",
        )
        worldModel = WorldModel()
      }
    } else {
      worldModel = WorldModel()
    }

    // Load all tasks into memory
    do {
      let allTasks = try taskManager.allTasks()
      for task in allTasks {
        // Store under both filename and UUID string
        var taskWithWorld = task
        taskWithWorld.taskWorld = self
        taskMap[task.idFile] = taskWithWorld
        taskMap[task.uuid.uuidString] = taskWithWorld
      }
    } catch {
      // If loading fails, start with empty map
      print("Warning: Failed to load tasks: \(error)")
    }
  }

  /// Search upward from current directory for .task-world.json
  /// Returns the directory containing .task-world.json, or current directory if
  /// not found
  private static func findProjectRoot() -> URL {
    var currentPath = FileManager.default.currentDirectoryPath
    let fileManager = FileManager.default

    // Traverse upwards looking for .task-world.json
    while true {
      let worldPath = URL(fileURLWithPath: currentPath)
        .appendingPathComponent(".task-world.json").path
      if fileManager.fileExists(atPath: worldPath) {
        return URL(fileURLWithPath: currentPath, isDirectory: true)
      }

      let parent = URL(fileURLWithPath: currentPath).deletingLastPathComponent()
        .path
      if parent == currentPath {
        // Reached filesystem root without finding .task-world.json
        // Fall back to current directory
        return URL(fileURLWithPath: currentPath, isDirectory: true)
      }

      currentPath = parent
    }
  }

  private func saveWorldState() {
    do {
      try worldModel.save(to: worldFilePath)
    } catch {
      print("Warning: Failed to save world state: \(error)")
    }
  }

  // MARK: - ITaskWorld Implementation

  public func createTask(name: String, summary: String) async throws -> Task {
    let maxRetries = 10
    var retries = 0

    while retries < maxRetries {
      do {
        let task = try Task.create(world: self, name: name, summary: summary)
        try taskManager.save(task)
        var taskWithWorld = task
        taskWithWorld.taskWorld = self
        taskMap[task.idFile] = taskWithWorld
        taskMap[task.uuid.uuidString] = taskWithWorld
        return taskWithWorld
      } catch TaskCreationError.filenameTaken {
        retries += 1
        if retries < maxRetries {
          do {
            try await _Concurrency.Task.sleep(nanoseconds: 1_000_000) // 1ms
          } catch {
            // If sleep is cancelled, continue immediately
          }
        }
      }
    }

    throw TaskCreationError
      .filenameTaken("Failed to create task after \(maxRetries) retries")
  }

  public func createTaskSync(name: String, summary: String) throws -> Task {
    let task = try Task.create(world: self, name: name, summary: summary)
    try taskManager.save(task)
    var taskWithWorld = task
    taskWithWorld.taskWorld = self
    taskMap[task.idFile] = taskWithWorld
    taskMap[task.uuid.uuidString] = taskWithWorld
    return taskWithWorld
  }

  public func taskFrom(anyId: AnyTaskId) -> Task? {
    taskMap[anyId]
  }

  public func allTaskIds(showFileName: Bool) -> [AnyTaskId] {
    if showFileName {
      // Return unique filenames (T_AZvuCKoac format)
      var seen = Set<String>()
      var result: [AnyTaskId] = []
      for (_, task) in taskMap {
        if !seen.contains(task.idFile) {
          seen.insert(task.idFile)
          result.append(task.idFile)
        }
      }
      return result
    } else {
      // Return unique UUID strings
      var seen = Set<String>()
      var result: [AnyTaskId] = []
      for (_, task) in taskMap {
        let uuidStr = task.uuid.uuidString
        if !seen.contains(uuidStr) {
          seen.insert(uuidStr)
          result.append(uuidStr)
        }
      }
      return result
    }
  }

  public func updateTask(_ task: Task) throws {
    try taskManager.save(task)
    var taskWithWorld = task
    taskWithWorld.taskWorld = self
    taskMap[task.idFile] = taskWithWorld
    taskMap[task.uuid.uuidString] = taskWithWorld
  }

  public func deleteTaskId(_ id: AnyTaskId) -> Bool {
    guard let task = taskMap[id] else { return false }
    do {
      let fileName = task.idFile + ".json"
      let fileURL = basePath.appendingPathComponent("Tasks")
        .appendingPathComponent(fileName)
      try FileManager.default.removeItem(at: fileURL)
      taskMap.removeValue(forKey: task.idFile)
      taskMap.removeValue(forKey: task.uuid.uuidString)
      return true
    } catch {
      return false
    }
  }

  public func stackTaskIds() -> [AnyTaskId] {
    worldModel.taskStack.map(\.uuidString)
  }

  public func pushTaskId(_ id: AnyTaskId) {
    if let task = taskMap[id] {
      worldModel.pushTask(task.uuid)
      saveWorldState()
    }
  }

  public func popTaskId() -> AnyTaskId? {
    guard let uuid = worldModel.popTask() else { return nil }
    saveWorldState()
    return uuid.uuidString
  }

  public func currentTaskId() -> AnyTaskId? {
    worldModel.currentTask().map(\.uuidString)
  }

  public func isStackTaskId(_ id: AnyTaskId) -> Bool {
    guard let task = taskMap[id] else { return false }
    return worldModel.taskStack.contains(task.uuid)
  }

  public func unstackTaskId(_ id: AnyTaskId) {
    guard let task = taskMap[id] else { return }
    let initialCount = worldModel.taskStack.count
    worldModel.taskStack.removeAll { $0 == task.uuid }
    if worldModel.taskStack.count != initialCount {
      saveWorldState()
    }
  }
}
