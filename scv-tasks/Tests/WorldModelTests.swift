import Testing
import UUIDV7
@testable import scvTasks
import Foundation

struct WorldModelTests {
  @Test
  func testWorldModelCreation() {
    let world = WorldModel()
    #expect(world.taskStack.isEmpty)
  }

  @Test
  func testPushTask() {
    let world = WorldModel()
    let uuid = UUIDV7()
    world.pushTask(uuid)
    #expect(world.taskStack.count == 1)
    #expect(world.currentTask() == uuid)
  }

  @Test
  func testPopTask() {
    let world = WorldModel()
    let uuid1 = UUIDV7()
    let uuid2 = UUIDV7()
    world.pushTask(uuid1)
    world.pushTask(uuid2)

    let popped = world.popTask()
    #expect(popped == uuid2)
    #expect(world.currentTask() == uuid1)
  }

  @Test
  func testClearStack() {
    let world = WorldModel()
    world.pushTask(UUIDV7())
    world.pushTask(UUIDV7())
    world.clearStack()
    #expect(world.taskStack.isEmpty)
  }

  @Test
  func testSaveAndLoad() throws {
    let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("world-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    let world = WorldModel()
    let uuid1 = UUIDV7()
    let uuid2 = UUIDV7()
    world.pushTask(uuid1)
    world.pushTask(uuid2)

    try world.save(to: tempFile)

    let loaded = try WorldModel.load(from: tempFile)
    #expect(loaded.taskStack.count == 2)
    #expect(loaded.taskStack[0] == uuid1)
    #expect(loaded.taskStack[1] == uuid2)
  }
}
