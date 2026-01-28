import Foundation
@testable import scvTasks
import Testing
import UUIDV7

struct TaskWorldTests {
  private func createTempDir() -> URL {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("taskworld-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
  }

  private func writeSampleTask(to dir: URL, uuid: UUIDV7, name: String) throws {
    let mockWorld = MockTaskWorld()
    let task = try Task.create(world: mockWorld, uuid: uuid, name: name, summary: "Sample task")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(task)
    let fileName = Task.uuidToFilename(uuid) + ".json"
    let fileURL = dir.appendingPathComponent("Tasks", isDirectory: true)
    try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
    try data.write(to: fileURL.appendingPathComponent(fileName))
  }

  @Test
  func taskWorldInitialization() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task1 = try await world.createTask(name: "Task 1", summary: "")
    let task2 = try await world.createTask(name: "Task 2", summary: "")

    let allIds = world.allTaskIds(showFileName: true)

    #expect(allIds.count == 2)
    #expect(allIds.contains(task1.idFile))
    #expect(allIds.contains(task2.idFile))
  }

  @Test
  func taskFromWithFileName() throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let uuid = UUIDV7()
    try writeSampleTask(to: tempDir, uuid: uuid, name: "Test Task")

    let world = TaskWorld(basePath: tempDir)
    let fileName = Task.uuidToFilename(uuid)
    let task = world.taskFrom(anyId: fileName)

    #expect(task != nil)
    #expect(task?.name == "Test Task")
    #expect(task?.uuid == uuid)
  }

  @Test
  func taskFromWithUUID() throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let uuid = UUIDV7()
    try writeSampleTask(to: tempDir, uuid: uuid, name: "Test Task")

    let world = TaskWorld(basePath: tempDir)
    let task = world.taskFrom(anyId: uuid.uuidString)

    #expect(task != nil)
    #expect(task?.name == "Test Task")
    #expect(task?.uuid == uuid)
  }

  @Test
  func allTaskIdsDeduplication() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task1 = try await world.createTask(name: "Task 1", summary: "")
    let task2 = try await world.createTask(name: "Task 2", summary: "")

    // showFileName: true should return unique filenames
    let fileNames = world.allTaskIds(showFileName: true)
    #expect(fileNames.count == 2)
    #expect(fileNames.contains(task1.idFile))
    #expect(fileNames.contains(task2.idFile))

    // showFileName: false should return unique UUIDs
    let uuids = world.allTaskIds(showFileName: false)
    #expect(uuids.count == 2)
    #expect(uuids.contains(task1.uuid.uuidString))
    #expect(uuids.contains(task2.uuid.uuidString))
  }

  @Test
  func pushAndPopTask() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task1 = try await world.createTask(name: "Task 1", summary: "")
    let task2 = try await world.createTask(name: "Task 2", summary: "")

    world.pushTaskId(task1.idFile)
    #expect(world.stackTaskIds().count == 1)

    world.pushTaskId(task2.idFile)
    #expect(world.stackTaskIds().count == 2)

    // Current task should be task2
    if let currentId = world.currentTaskId(), let currentTask = world.taskFrom(anyId: currentId) {
      #expect(currentTask.uuid == task2.uuid)
    } else {
      #expect(Bool(false), "Current task not found")
    }

    // Pop should return task2
    let popped = world.popTaskId()
    #expect(popped != nil)
    if let poppedId = popped {
      let poppedTask = world.taskFrom(anyId: poppedId)
      #expect(poppedTask != nil)
      if let poppedTask = poppedTask {
        #expect(poppedTask.uuid == task2.uuid)
      }
    }

    // Stack should now have 1 item
    #expect(world.stackTaskIds().count == 1)

    // Current task should now be task1
    let currentId = world.currentTaskId()
    #expect(currentId != nil)
    if let currentId = currentId {
      let currentTask = world.taskFrom(anyId: currentId)
      #expect(currentTask != nil)
      if let currentTask = currentTask {
        #expect(currentTask.uuid == task1.uuid)
      }
    }
  }

  @Test
  func isStackTaskId() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task = try await world.createTask(name: "Task 1", summary: "")

    #expect(!world.isStackTaskId(task.idFile))

    world.pushTaskId(task.idFile)
    #expect(world.isStackTaskId(task.idFile))

    let stack = world.stackTaskIds()
    #expect(stack.count == 1)
    #expect(world.taskFrom(anyId: stack[0])?.uuid == task.uuid)

    if let currentId = world.currentTaskId(), let currentTask = world.taskFrom(anyId: currentId) {
      #expect(currentTask.uuid == task.uuid)
    } else {
      #expect(Bool(false), "Current task not found after push")
    }
  }

  @Test
  func unstackTaskId() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task1 = try await world.createTask(name: "Task 1", summary: "")
    let task2 = try await world.createTask(name: "Task 2", summary: "")

    world.pushTaskId(task1.idFile)
    world.pushTaskId(task2.idFile)

    world.unstackTaskId(task1.idFile)
    let stack = world.stackTaskIds()

    #expect(stack.count == 1)
    // stack[0] is a UUID string or filename, verify it resolves to task2
    if let stackedTask = world.taskFrom(anyId: stack[0]) {
      #expect(stackedTask.uuid == task2.uuid)
    } else {
      #expect(Bool(false), "Stacked task not found")
    }
  }

  @Test
  func updateTaskPersists() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    var task = try await world.createTask(name: "Original Name", summary: "")

    task.name = "Updated Name"
    try world.updateTask(task)

    // Verify update persisted by reloading
    let world2 = TaskWorld(basePath: tempDir)
    let reloadedTask = world2.taskFrom(anyId: task.idFile)

    #expect(reloadedTask?.name == "Updated Name")
  }

  @Test
  func deleteTaskId() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task = try await world.createTask(name: "Task to Delete", summary: "")

    #expect(world.taskFrom(anyId: task.idFile) != nil)

    let deleted = world.deleteTaskId(task.idFile)
    #expect(deleted == true)
    #expect(world.taskFrom(anyId: task.idFile) == nil)
  }

  @Test
  func stackTaskReturnedWhenAvailable() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task1 = try await world.createTask(name: "Task 1", summary: "")
    let task2 = try await world.createTask(name: "Task 2", summary: "")
    let task3 = try await world.createTask(name: "Task 3", summary: "")

    // Stack should be empty
    #expect(world.stackTaskIds().isEmpty)

    // After pushing task2, currentTaskId() should return task2
    world.pushTaskId(task2.idFile)
    if let currentId = world.currentTaskId() {
      let currentTask = world.taskFrom(anyId: currentId)
      #expect(currentTask?.uuid == task2.uuid)
    } else {
      #expect(Bool(false), "currentTaskId() returned nil when stack is not empty")
    }
  }

  @Test
  func multipleStackedTasksReturnTopOfStack() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task1 = try await world.createTask(name: "Task 1", summary: "")
    let task2 = try await world.createTask(name: "Task 2", summary: "")
    let task3 = try await world.createTask(name: "Task 3", summary: "")

    // Push task1, then task2 to stack
    world.pushTaskId(task1.idFile)
    world.pushTaskId(task2.idFile)

    // currentTaskId() should return task2 (top of stack)
    if let currentId = world.currentTaskId() {
      let currentTask = world.taskFrom(anyId: currentId)
      #expect(currentTask?.uuid == task2.uuid)
    } else {
      #expect(Bool(false), "currentTaskId() returned nil when stack is not empty")
    }
  }
}
