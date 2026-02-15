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

  // MARK: - Task Resolution

  /// Resolve a task by id (filename or UUID prefix) or current task from stack.
  /// - Parameter id: Optional task identifier. If nil, returns current task from stack.
  ///   If provided, can be:
  ///   - UUID string (36 chars with dashes): matches by exact UUID
  ///   - Filename (T_AZvuCKoac): matches by prefix (case-insensitive)
  /// - Throws: TaskResolutionError.notFound if task not found, or .ambiguous if multiple
  ///   tasks match the prefix
  public func resolveTask(id: AnyTaskId?) throws -> Task {
    let taskId: AnyTaskId
    if let id = id {
      taskId = id
    } else {
      guard let currentId = currentTaskId() else {
        throw TaskResolutionError.notFound("(no current task)")
      }
      taskId = currentId
    }
    return try resolveTaskLevenstein(taskId)
  }

  /// Resolve a task using two-stage Levenshtein fuzzy matching with distance threshold.
  ///
  /// **Algorithm:**
  /// - Distance threshold: `max(1, query.length - 3)` - requires ~3 chars overlap minimum
  /// - Stage 1 (case-sensitive): Calculate distance to all tasks; if closest distance exceeds threshold, throw notFound
  /// - Stage 2 (case-insensitive tiebreaker): Among Stage 1 matches, recalculate case-insensitively to break ties
  ///
  /// **Rationale:**
  /// - Base64 filenames are case-sensitive, but user typos often involve case errors
  /// - Stage 1 preserves base64 fidelity; Stage 2 handles case typos gracefully
  /// - Distance threshold prevents accepting terrible matches (e.g., "T_NONEXISTENT" shouldn't match "T_AZxjfXGpc")
  /// - Deduplication avoids spurious duplicates from taskMap (stores each task by both filename and UUID)
  ///
  /// **Returns:** Unique matched task; throws notFound if too far, ambiguous if tied
  private func resolveTaskLevenstein(_ query: AnyTaskId) throws -> Task {
    let distanceThreshold = max(1, query.count - 2)

    // Stage 1: Case-sensitive Levenshtein distance
    var stage1Results: [(task: Task, distance: Int)] = []
    var seenIds = Set<String>()

    for (_, task) in taskMap {
      // Skip duplicates (taskMap stores each task by both filename and UUID)
      guard !seenIds.contains(task.idFile) else { continue }
      seenIds.insert(task.idFile)

      let filenameDist = levenshtein(task.idFile, query, ignoreCase: false)
      let uuidDist = levenshtein(task.uuid.uuidString, query, ignoreCase: false)
      let minDist = min(filenameDist, uuidDist)
      stage1Results.append((task: task, distance: minDist))
    }

    guard !stage1Results.isEmpty else {
      let msg = "no matches for \(query)"
      throw TaskResolutionError.notFound(msg)
    }

    // Find minimum case-sensitive distance
    let minCaseSensitiveDistance = stage1Results.min(by: { $0.distance < $1.distance })!
      .distance
    if minCaseSensitiveDistance > distanceThreshold {
      let msg = "\(query) distanceThreshold exceeded: \(minCaseSensitiveDistance) > \(distanceThreshold)"
      throw TaskResolutionError.notFound(msg)
    }

    let shortList = stage1Results.filter { $0.distance == minCaseSensitiveDistance }

    // If unique at stage 1, return it
    if shortList.count == 1 {
      return shortList[0].task
    }

    // Stage 2: Case-insensitive Levenshtein distance as tiebreaker
    var stage2Results: [(task: Task, distance: Int)] = []

    for (task, _) in shortList {
      let filenameDist = levenshtein(task.idFile, query, ignoreCase: true)
      let uuidDist = levenshtein(task.uuid.uuidString, query, ignoreCase: true)
      let minDist = min(filenameDist, uuidDist)
      stage2Results.append((task: task, distance: minDist))
    }

    // Find minimum case-insensitive distance
    let minCaseInsensitiveDistance = stage2Results.min(by: { $0.distance < $1.distance })!
      .distance
    let finalList = stage2Results.filter { $0.distance == minCaseInsensitiveDistance }

    // If unique after tiebreaker, return it
    if finalList.count == 1 {
      return finalList[0].task
    }

    // Still ambiguous after both stages
    let matchIds = finalList.map { $0.task.idFile }.sorted()
    print("ambiguous matches for \(query):", matchIds)
    throw TaskResolutionError.ambiguous(query, matchIds)
  }

  /// Compute Levenshtein distance (edit distance) between two strings.
  /// Counts minimum insertions, deletions, and substitutions needed to transform a→b.
  /// Used in resolveTaskLevenstein for both case-sensitive (stage 1) and case-insensitive (stage 2) matching.
  public func levenshtein(_ a: String, _ b: String, ignoreCase: Bool = false) -> Int {
    let a = ignoreCase ? a.lowercased() : a
    let b = ignoreCase ? b.lowercased() : b

    let aChars = Array(a)
    let bChars = Array(b)

    var matrix = Array(
      repeating: Array(repeating: 0, count: bChars.count + 1),
      count: aChars.count + 1
    )

    for i in 0 ... aChars.count {
      matrix[i][0] = i
    }
    for j in 0 ... bChars.count {
      matrix[0][j] = j
    }

    for i in 1 ... aChars.count {
      for j in 1 ... bChars.count {
        let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
        matrix[i][j] = min(
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost // substitution
        )
      }
    }

    return matrix[aChars.count][bChars.count]
  }
}
