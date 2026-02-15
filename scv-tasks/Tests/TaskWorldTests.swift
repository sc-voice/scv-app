import Foundation
@testable import scvTasks
import Testing
import UUIDV7

struct TaskWorldTests {
  static let REAL_TASKS = [
    ("T_AZv_4Rvsc", "019BFFE1-1BEC-7000-9AD2-49A03FDC0945"),
    ("T_AZvt220Rc", "019BEDDB-6D11-7000-B516-2BD4E3E7A2E2"),
    ("T_AZvt220Xc", "019BEDDB-6D17-7000-8A23-6C321726DFEF"),
    ("T_AZvt220dc", "019BEDDB-6D1D-7000-AC8D-737FCFCF9DD0"),
    ("T_AZvt220ic", "019BEDDB-6D22-7000-9F74-FC8E478C4D16"),
    ("T_AZvt220nc", "019BEDDB-6D27-7000-9679-0592798D3EE6"),
    ("T_AZvt220uc", "019BEDDB-6D2E-7000-8919-319F7F57907F"),
    ("T_AZvt26U1c", "019BEDDB-A535-7000-9EC6-3FF2D8CE93BC"),
    ("T_AZvt26U7c", "019BEDDB-A53B-7000-B9E7-E3A317E12133"),
    ("T_AZvt26VBc", "019BEDDB-A541-7000-A6E7-CCFBAA5DE78B"),
    ("T_AZvt26VLc", "019BEDDB-A54B-7000-9C73-A7FCD7DCADE2"),
    ("T_AZvttSc4c", "019BEDB5-2738-7000-8D8A-C7C5CCC3841B"),
    ("T_AZvuCKoac", "019BEE08-AA1A-7000-BA3E-A27231CAED05"),
    ("T_AZw0oQKfc", "019C34A1-029F-7000-96B4-BFD40E762FEC"),
    ("T_AZwMeH04c", "019C0C78-7D38-7000-877D-A92F8CF85B9B"),
    ("T_AZwQOdIwc", "019C1039-D230-7000-B6DB-23CDCD85DA8C"),
    ("T_AZwUEeoNc", "019C1411-EA0D-7000-BDBF-E2236299CCA5"),
    ("T_AZwZdMBoc", "019C1974-C068-7000-846F-2C52A19E3C2C"),
    ("T_AZwZsgFWc", "019C19B2-0156-7000-94CE-6D42E2F95AE6"),
    ("T_AZwkidSQc", "019C2489-D490-7000-84C7-5C7600EABF39"),
    ("T_AZwyuQKWc", "019C32B9-0296-7000-ADB1-1DE6925CB05A"),
    ("T_AZwzMtyTc", "019C3332-DC93-7000-88F9-DC53E24F3D22"),
    ("T_AZwzXssCc", "019C335E-CB02-7000-9402-91F63F624D5F"),
    ("T_AZxHTYicc", "019C474D-889C-7000-85D1-A0BD0A8C322D"),
    ("T_AZxOmq97c", "019C4E9A-AF7B-7000-B0B9-475336C90CCC"),
    ("T_AZxcM80Bc", "019C5C33-CD01-7000-98F2-9B83AD660BC8"),
    ("T_AZxeARVEc", "019C5E01-1544-7000-BB49-B0B78055F41B"),
    ("T_AZxhwXE7c", "019C61C1-713B-7000-8056-D32844EE5B9F"),
    ("T_AZxi-GS7c", "019C62F8-64BB-7000-AAF8-0A682304B4F5"),
    ("T_AZxieJ3Ec", "019C6278-9DC4-7000-8C02-5D18CE775C74"),
  ]

  private func createTempDir() -> URL {
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(
        "taskworld-\(UUID().uuidString)",
        isDirectory: true,
      )
    try? FileManager.default.createDirectory(
      at: tempDir,
      withIntermediateDirectories: true,
    )
    return tempDir
  }

  private func writeSampleTask(to dir: URL, uuid: UUIDV7, name: String) throws {
    let mockWorld = MockTaskWorld()
    let task = try Task.create(
      world: mockWorld,
      uuid: uuid,
      name: name,
      summary: "Sample task",
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(task)
    let fileName = Task.uuidToFilename(uuid) + ".json"
    let fileURL = dir.appendingPathComponent("Tasks", isDirectory: true)
    try FileManager.default.createDirectory(
      at: fileURL,
      withIntermediateDirectories: true,
    )
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
    if let currentId = world.currentTaskId(),
       let currentTask = world.taskFrom(anyId: currentId)
    {
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
      if let poppedTask {
        #expect(poppedTask.uuid == task2.uuid)
      }
    }

    // Stack should now have 1 item
    #expect(world.stackTaskIds().count == 1)

    // Current task should now be task1
    let currentId = world.currentTaskId()
    #expect(currentId != nil)
    if let currentId {
      let currentTask = world.taskFrom(anyId: currentId)
      #expect(currentTask != nil)
      if let currentTask {
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

    if let currentId = world.currentTaskId(),
       let currentTask = world.taskFrom(anyId: currentId)
    {
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
    _ = try await world.createTask(name: "Task 3", summary: "")

    // Stack should be empty
    #expect(world.stackTaskIds().isEmpty)

    // After pushing task2, currentTaskId() should return task2
    world.pushTaskId(task2.idFile)
    if let currentId = world.currentTaskId() {
      let currentTask = world.taskFrom(anyId: currentId)
      #expect(currentTask?.uuid == task2.uuid)
    } else {
      #expect(
        Bool(false),
        "currentTaskId() returned nil when stack is not empty",
      )
    }
  }

  @Test
  func multipleStackedTasksReturnTopOfStack() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task1 = try await world.createTask(name: "Task 1", summary: "")
    let task2 = try await world.createTask(name: "Task 2", summary: "")
    _ = try await world.createTask(name: "Task 3", summary: "")

    // Push task1, then task2 to stack
    world.pushTaskId(task1.idFile)
    world.pushTaskId(task2.idFile)

    // currentTaskId() should return task2 (top of stack)
    if let currentId = world.currentTaskId() {
      let currentTask = world.taskFrom(anyId: currentId)
      #expect(currentTask?.uuid == task2.uuid)
    } else {
      #expect(
        Bool(false),
        "currentTaskId() returned nil when stack is not empty",
      )
    }
  }

  // MARK: - resolveTask tests

  @Test
  func resolveTaskWithNilAndEmptyStack() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    _ = try await world.createTask(name: "Task 1", summary: "")

    // resolveTask(id: nil) with empty stack should throw
    #expect(throws: TaskResolutionError.self) {
      _ = try world.resolveTask(id: nil)
    }
  }

  @Test
  func resolveTaskWithNilAndCurrentTask() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task = try await world.createTask(name: "Current Task", summary: "")

    // Push to stack
    world.pushTaskId(task.idFile)

    // resolveTask(id: nil) should return current task
    let resolved = try world.resolveTask(id: nil)
    #expect(resolved.uuid == task.uuid)
    #expect(resolved.name == "Current Task")
  }

  @Test
  func resolveTaskByExactFilePrefix() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task = try await world.createTask(name: "Exact Match Task", summary: "")

    // Resolve by exact filename
    let resolved = try world.resolveTask(id: task.idFile)
    #expect(resolved.uuid == task.uuid)
    #expect(resolved.name == "Exact Match Task")
  }

  @Test
  func resolveTaskByPartialFilePrefix() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task = try await world.createTask(name: "Partial Match Task", summary: "")

    // Get first 8 chars of filename (T_AZxjl...)
    let prefix = String(task.idFile.prefix(8))
    let resolved = try world.resolveTask(id: prefix)
    #expect(resolved.uuid == task.uuid)
  }

  @Test
  func resolveTaskByUUID() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task = try await world.createTask(name: "UUID Task", summary: "")

    // Resolve by UUID string
    let resolved = try world.resolveTask(id: task.uuid.uuidString)
    #expect(resolved.uuid == task.uuid)
  }

  @Test
  func resolveTaskCaseInsensitive() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task = try await world.createTask(name: "Case Task", summary: "")

    // Try lowercase prefix
    let prefix = task.idFile.lowercased()
    let resolved = try world.resolveTask(id: prefix)
    #expect(resolved.uuid == task.uuid)
  }

  @Test
  func resolveTaskWithoutT_Prefix() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task = try await world.createTask(name: "No Prefix Task", summary: "")

    // Resolve without T_ prefix (should be added automatically)
    let prefixWithoutT = String(task.idFile.dropFirst(2))
    let resolved = try world.resolveTask(id: prefixWithoutT)
    #expect(resolved.uuid == task.uuid)
  }

  @Test
  func resolveTaskLowercaseWithoutT_Prefix() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    let task = try await world.createTask(name: "Lowercase Prefix Task", summary: "")

    // Resolve using lowercase prefix without T_ (e.g., "azxvt220r" for "T_AZXvt220R")
    let lowercasePrefixWithoutT = String(task.idFile.dropFirst(2)).lowercased()
    let resolved = try world.resolveTask(id: lowercasePrefixWithoutT)
    #expect(resolved.uuid == task.uuid)
  }

  @Test
  func resolveTaskAmbiguousMatches() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    // Create multiple tasks to get potential prefix collisions
    let task1 = try await world.createTask(name: "Task A", summary: "")
    let task2 = try await world.createTask(name: "Task B", summary: "")
    let task3 = try await world.createTask(name: "Task C", summary: "")

    // Use prefix that matches multiple tasks (first 8 chars should be common to at least 2)
    let commonPrefix = String(task1.idFile.prefix(8))

    // Should throw ambiguous error
    var caught = false
    do {
      _ = try world.resolveTask(id: commonPrefix)
    } catch let error as TaskResolutionError {
      if case .ambiguous = error {
        caught = true
      }
    }
    #expect(caught, "Expected TaskResolutionError.ambiguous")
  }

  @Test
  func resolveTaskNotFound() async throws {
    let tempDir = createTempDir()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let world = TaskWorld(basePath: tempDir)
    _ = try await world.createTask(name: "Some Task", summary: "")

    // Try to resolve non-existent task
    var caught = false
    do {
      _ = try world.resolveTask(id: "T_NONEXISTENT")
    } catch let error as TaskResolutionError {
      if case .notFound = error {
        caught = true
      }
    }
    #expect(caught, "Expected TaskResolutionError.notFound")
  }
}
