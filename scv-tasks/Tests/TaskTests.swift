import Testing
import UUIDV7
@testable import scvTasks

struct TaskTests {
  @Test
  func testTaskCreation() {
    let uuid = UUIDV7()
    let task = Task(
      id: uuid,
      name: "Test Task",
      summary: "A test task"
    )
    #expect(task.id == uuid)
    #expect(task.name == "Test Task")
    #expect(task.summary == "A test task")
    #expect(task.state == .active)
  }

  @Test
  func testTaskIsBlocked() {
    var task = Task(
      id: UUIDV7(),
      name: "Test",
      summary: "Test",
      state: .blocked
    )
    #expect(task.isBlocked)
    #expect(!task.isActive)
    #expect(!task.isDone)

    task.updateState(.active)
    #expect(!task.isBlocked)
    #expect(task.isActive)
  }

  @Test
  func testMoveActionToCompleted() {
    var task = Task(
      id: UUIDV7(),
      name: "Test",
      summary: "Test",
      plannedActions: [
        Action(description: "Action 1"),
        Action(description: "Action 2"),
      ]
    )

    #expect(task.plannedActions.count == 2)
    #expect(task.completedActions.count == 0)

    task.moveActionToCompleted(at: 0)

    #expect(task.plannedActions.count == 1)
    #expect(task.completedActions.count == 1)
    #expect(task.completedActions[0].description == "Action 1")
  }

  @Test
  func testAddPlannedAction() {
    var task = Task(
      id: UUIDV7(),
      name: "Test",
      summary: "Test"
    )

    let action = Action(description: "New action")
    task.addPlannedAction(action)

    #expect(task.plannedActions.count == 1)
    #expect(task.plannedActions[0].description == "New action")
  }

  @Test
  func testFileName() {
    let uuid = UUIDV7()
    let task = Task(
      id: uuid,
      name: "Test",
      summary: "Test"
    )
    // fileName should start with T_ and have 9 base64 chars
    #expect(task.fileName.hasPrefix("T_"))
    #expect(task.fileName.count == 11) // "T_" + 9 chars
  }
}
