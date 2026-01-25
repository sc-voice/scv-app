@testable import scvTasks
import Testing

struct TaskStateTests {
  @Test
  func taskStateRawValues() {
    #expect(TaskState.blocked.rawValue == "blocked")
    #expect(TaskState.active.rawValue == "active")
    #expect(TaskState.done.rawValue == "done")
  }
}
