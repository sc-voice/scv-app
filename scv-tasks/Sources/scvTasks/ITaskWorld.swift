import Foundation
import UUIDV7

/// AnyTaskId is a string used to match a unique task using resolveTask()
/// AnyTaskId can be TaskTID, TaskId, or a resolvable string
public typealias AnyTaskId = String

/// The URL-save base64 rendition of the UUIDV7
public typealias TaskTID = String

/// The time-based UUID for a task is unique but too large for humans
public typealias TaskId = UUIDV7

/// ITaskWorld defines the complete API for task management.
/// All code should interact with tasks through this protocol.
/// All mutations are atomic and durable - no explicit save() needed.
public protocol ITaskWorld: AnyObject, Sendable {
  // Task queries
  func taskFrom(anyId: AnyTaskId) -> Task?
  func allTaskIds(showFileName: Bool) -> [AnyTaskId]
  func resolveTask(id: AnyTaskId?) throws -> Task

  // Task creation and mutations (atomic and durable)
  func createTask(name: String, summary: String) async throws -> Task
  func createTaskSync(name: String, summary: String) throws -> Task
  func updateTask(_ task: Task) throws
  func deleteTaskId(_ id: AnyTaskId) -> Bool

  // Task stack (context switching, atomic and durable)
  func stackTaskIds() -> [AnyTaskId]
  func pushTaskId(_ id: AnyTaskId)
  func popTaskId() -> AnyTaskId?
  func currentTaskId() -> AnyTaskId?
  func isStackTaskId(_ id: AnyTaskId) -> Bool
  func unstackTaskId(_ id: AnyTaskId)

  // User preferences
  var limit: Int { get set }
  var verbosity: Int { get set }
  var lineLength: Int { get set }
  var testDefault: String { get set }
}
