@testable import scvTasks
import Foundation
import UUIDV7

/// MockTaskWorld for unit testing. Lightweight in-memory implementation of ITaskWorld.
class MockTaskWorld: ITaskWorld, @unchecked Sendable {
  private var taskMap: [String: Task] = [:]
  private var _taskStack: [UUIDV7] = []

  public var limit: Int = 20
  public var verbosity: Int = 1
  public var lineLength: Int = 80

  public func createTask(name: String, summary: String) async throws -> Task {
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
            try await _Concurrency.Task.sleep(nanoseconds: 1_000_000)  // 1ms
          } catch {
            // If sleep is cancelled, continue immediately
          }
        }
      }
    }

    throw TaskCreationError.filenameTaken("Failed to create task after \(maxRetries) retries")
  }

  public func createTaskSync(name: String, summary: String) throws -> Task {
    let task = try Task.create(world: self, name: name, summary: summary)
    var taskWithWorld = task
    taskWithWorld.taskWorld = self
    taskMap[task.idFile] = taskWithWorld
    taskMap[task.uuid.uuidString] = taskWithWorld
    return taskWithWorld
  }

  /// Test helper: create task with specific UUID for deterministic testing
  func createTask(uuid: UUIDV7, name: String, summary: String) async throws -> Task {
    let task = try Task.create(world: self, uuid: uuid, name: name, summary: summary)
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

  public func updateTask(_ task: Task) throws {
    var taskWithWorld = task
    taskWithWorld.taskWorld = self
    taskMap[task.idFile] = taskWithWorld
    taskMap[task.uuid.uuidString] = taskWithWorld
  }

  public func deleteTaskId(_ id: AnyTaskId) -> Bool {
    guard let task = taskMap[id] else { return false }
    taskMap.removeValue(forKey: task.idFile)
    taskMap.removeValue(forKey: task.uuid.uuidString)
    return true
  }

  public func stackTaskIds() -> [AnyTaskId] {
    _taskStack.map { $0.uuidString }
  }

  public func pushTaskId(_ id: AnyTaskId) {
    if let task = taskMap[id] {
      _taskStack.append(task.uuid)
    }
  }

  public func popTaskId() -> AnyTaskId? {
    guard let uuid = _taskStack.popLast() else { return nil }
    return uuid.uuidString
  }

  public func currentTaskId() -> AnyTaskId? {
    _taskStack.last.map { $0.uuidString }
  }

  public func isStackTaskId(_ id: AnyTaskId) -> Bool {
    guard let task = taskMap[id] else { return false }
    return _taskStack.contains(task.uuid)
  }

  public func unstackTaskId(_ id: AnyTaskId) {
    guard let task = taskMap[id] else { return }
    _taskStack.removeAll { $0 == task.uuid }
  }
}
