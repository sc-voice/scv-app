import Testing
import UUIDV7
@testable import scvTasks
import Foundation

struct TaskManagerTests {
  @Test
  func testTaskManagerInitialization() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let manager = TaskManager(basePath: tempDir)
    #expect(manager.getCurrentTask() == nil)
  }

  @Test
  func testSetAndGetCurrentTask() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let manager = TaskManager(basePath: tempDir)

    let uuid = UUIDV7()
    let task = Task(
      id: uuid,
      name: "Test Task",
      summary: "A test task"
    )

    try manager.setCurrentTask(task)

    let retrieved = manager.getCurrentTask()

    #expect(retrieved?.id == uuid)
    #expect(retrieved?.name == "Test Task")
  }
}
