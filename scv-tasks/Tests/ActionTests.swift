import Foundation
@testable import scvTasks
import Testing

struct ActionTests {
  @Test
  func actionCreation() {
    let action = Action(description: "Do something")
    #expect(action.description == "Do something")
    #expect(action.taskId == nil)
  }

  @Test
  func actionWithTaskId() {
    let action = Action(description: "Do something", taskId: "task-123")
    #expect(action.description == "Do something")
    #expect(action.taskId == "task-123")
  }

  @Test
  func actionCodable() throws {
    let action = Action(description: "Test action", taskId: "task-456")
    let encoder = JSONEncoder()
    let data = try encoder.encode(action)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Action.self, from: data)
    #expect(decoded.description == action.description)
    #expect(decoded.taskId == action.taskId)
  }
}
