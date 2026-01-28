import Foundation
@testable import scvTasks
import Testing
import UUIDV7

struct TaskManagerTests {
  @Test
  func taskManagerInitialization() throws {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(
        UUID().uuidString,
        isDirectory: true,
      )
    try FileManager.default.createDirectory(
      at: tempDir,
      withIntermediateDirectories: true,
    )
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let manager = TaskManager(basePath: tempDir)
    let tasks = try manager.allTasks()
    #expect(tasks.isEmpty)
  }
}
