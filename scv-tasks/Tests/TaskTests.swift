@testable import scvTasks
import Testing
import UUIDV7

struct TaskTests {
  @Test
  func taskCreation() async throws {
    let world = MockTaskWorld()
    let uuid = UUIDV7(timeIntervalSince1970: 0, UInt32(1))
    let task = try Task.create(
      world: world,
      uuid: uuid,
      name: "Test Task",
      summary: "A test task",
    )

    #expect(task.uuid == uuid)
    #expect(task.name == "Test Task")
    #expect(task.summary == "A test task")
    #expect(task.state == TaskState.pending)
  }

  @Test
  func taskIsBlocked() async throws {
    let world = MockTaskWorld()
    let uuid = UUIDV7(timeIntervalSince1970: 0, UInt32(2))
    var task = try Task.create(
      world: world,
      uuid: uuid,
      name: "Test",
      summary: "Test",
    )
    task.requiredTasks = ["T_blockedTask"]
    try world.updateTask(task)

    // Without blocker in world, state is computed as .pending
    #expect(task.state == TaskState.pending)
    #expect(!task.isBlocked)
    #expect(!task.isActive)
    #expect(!task.isDone)
  }

  @Test
  func testMoveActionToCompleted() async throws {
    let world = MockTaskWorld()
    let uuid = UUIDV7(timeIntervalSince1970: 0, UInt32(3))
    var task = try Task.create(
      world: world,
      uuid: uuid,
      name: "Test",
      summary: "Test",
    )
    task.plannedActions = [
      Action(description: "Action 1"),
      Action(description: "Action 2"),
    ]
    try world.updateTask(task)

    #expect(task.plannedActions.count == 2)
    #expect(task.completedActions.count == 0)

    task.moveActionToCompleted(at: 0)

    #expect(task.plannedActions.count == 1)
    #expect(task.completedActions.count == 1)
    #expect(task.completedActions[0].description == "Action 1")
  }

  @Test
  func testAddPlannedAction() async throws {
    let world = MockTaskWorld()
    let uuid = UUIDV7(timeIntervalSince1970: 0, UInt32(4))
    var task = try Task.create(
      world: world,
      uuid: uuid,
      name: "Test",
      summary: "Test",
    )

    let action = Action(description: "New action")
    task.addPlannedAction(action)

    #expect(task.plannedActions.count == 1)
    #expect(task.plannedActions[0].description == "New action")
  }

  @Test
  func fileName() async throws {
    let world = MockTaskWorld()
    let uuid = UUIDV7(timeIntervalSince1970: 0, UInt32(5))
    let task = try Task.create(
      world: world,
      uuid: uuid,
      name: "Test",
      summary: "Test",
    )

    // idFile should start with T_ and have 9 base64 chars
    #expect(task.idFile.hasPrefix("T_"))
    #expect(task.idFile.count == 11) // "T_" + 9 chars
  }

  @Test
  func shortIdTest() throws {
    // verify that actionId will be unique and shjort
    let uuid1 = UUIDV7()
    let uuid2 = UUIDV7()
    let id1 = Task.shortId(uuid1)
    let id2 = Task.shortId(uuid2)
    print("id1:\(id1)")
    print("id2:\(id2)")
    #expect(id1 != id2)
    #expect(id1.count == 8)
  }
}
