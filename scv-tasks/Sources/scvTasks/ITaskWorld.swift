import Foundation
import UUIDV7

/// AnyTaskId can be either a filename string (e.g., "T_AZvuCKoac") or UUID
/// string
public typealias AnyTaskId = String

/// ITaskWorld defines the complete API for task management.
/// All code should interact with tasks through this protocol.
/// All mutations are atomic and durable - no explicit save() needed.
public protocol ITaskWorld: AnyObject, Sendable {
  // Task queries
  func taskFrom(anyId: AnyTaskId) -> Task?
  func allTaskIds(showFileName: Bool) -> [AnyTaskId]

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
