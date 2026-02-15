import Foundation
@testable import scvTasks
import UUIDV7

/// MockTaskWorld for unit testing. Lightweight in-memory implementation of
/// ITaskWorld.
class MockTaskWorld: ITaskWorld, @unchecked Sendable {
  private var taskMap: [String: Task] = [:]
  private var _taskStack: [UUIDV7] = []

  var limit: Int = 20
  var verbosity: Int = 1
  var lineLength: Int = 80
  var testDefault: String = TaskWorld.TEST_DEFAULT

  func createTask(name: String, summary: String) async throws -> Task {
    let maxRetries = 10
    var retries = 0

    while retries < maxRetries {
      do {
        let task = try Task.create(world: self, name: name, summary: summary)
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

  func createTaskSync(name: String, summary: String) throws -> Task {
    let task = try Task.create(world: self, name: name, summary: summary)
    var taskWithWorld = task
    taskWithWorld.taskWorld = self
    taskMap[task.idFile] = taskWithWorld
    taskMap[task.uuid.uuidString] = taskWithWorld
    return taskWithWorld
  }

  /// Test helper: create task with specific UUID for deterministic testing
  func createTask(uuid: UUIDV7, name: String,
                  summary: String) async throws -> Task
  {
    let task = try Task.create(
      world: self,
      uuid: uuid,
      name: name,
      summary: summary,
    )
    var taskWithWorld = task
    taskWithWorld.taskWorld = self
    taskMap[task.idFile] = taskWithWorld
    taskMap[task.uuid.uuidString] = taskWithWorld
    return taskWithWorld
  }

  func taskFrom(anyId: AnyTaskId) -> Task? {
    taskMap[anyId]
  }

  func allTaskIds(showFileName: Bool) -> [AnyTaskId] {
    if showFileName {
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

  func updateTask(_ task: Task) throws {
    var taskWithWorld = task
    taskWithWorld.taskWorld = self
    taskMap[task.idFile] = taskWithWorld
    taskMap[task.uuid.uuidString] = taskWithWorld
  }

  func deleteTaskId(_ id: AnyTaskId) -> Bool {
    guard let task = taskMap[id] else { return false }
    taskMap.removeValue(forKey: task.idFile)
    taskMap.removeValue(forKey: task.uuid.uuidString)
    return true
  }

  func stackTaskIds() -> [AnyTaskId] {
    _taskStack.map(\.uuidString)
  }

  func pushTaskId(_ id: AnyTaskId) {
    if let task = taskMap[id] {
      _taskStack.append(task.uuid)
    }
  }

  func popTaskId() -> AnyTaskId? {
    guard let uuid = _taskStack.popLast() else { return nil }
    return uuid.uuidString
  }

  func currentTaskId() -> AnyTaskId? {
    _taskStack.last.map(\.uuidString)
  }

  func isStackTaskId(_ id: AnyTaskId) -> Bool {
    guard let task = taskMap[id] else { return false }
    return _taskStack.contains(task.uuid)
  }

  func unstackTaskId(_ id: AnyTaskId) {
    guard let task = taskMap[id] else { return }
    _taskStack.removeAll { $0 == task.uuid }
  }

  func resolveTask(id: AnyTaskId?) throws -> Task {
    // If id is nil, resolve to current task from stack
    if let id = id {
      // Explicit task provided - resolve by id/prefix
      return try resolveTaskByQuery(id)
    } else {
      // No task specified - use current task from stack
      if let currentId = currentTaskId() {
        guard let task = taskFrom(anyId: currentId) else {
          throw TaskResolutionError.notFound(currentId)
        }
        return task
      } else {
        // Stack is empty - no current task
        throw TaskResolutionError.notFound("(no current task)")
      }
    }
  }

  private func resolveTaskByQuery(_ query: String) throws -> Task {
    // If query looks like a UUID string, find by exact UUID
    if query.count == 36, query.contains("-") {
      if let task = taskMap[query] {
        return task
      }
      throw TaskResolutionError.notFound(query)
    }

    // Treat as filename prefix; ensure it starts with T_
    let upperQuery = query.uppercased()
    let prefix = upperQuery.hasPrefix("T_") ? upperQuery : "T_" + upperQuery

    // Exact prefix match (case-sensitive)
    var matchingTasks = allTaskIds(showFileName: true)
      .compactMap { taskMap[$0] }
      .filter { $0.idFile.hasPrefix(prefix) }

    // Fallback to case-insensitive match if no exact matches
    if matchingTasks.isEmpty {
      matchingTasks = allTaskIds(showFileName: true)
        .compactMap { taskMap[$0] }
        .filter { $0.idFile.lowercased().hasPrefix(prefix.lowercased()) }
    }

    guard !matchingTasks.isEmpty else {
      throw TaskResolutionError.notFound(prefix)
    }

    guard matchingTasks.count == 1 else {
      let matchIds = matchingTasks.map(\.idFile).sorted()
      throw TaskResolutionError.ambiguous(prefix, matchIds)
    }

    return matchingTasks[0]
  }
}
