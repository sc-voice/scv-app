import Testing
@testable import scvTasks

struct TaskStateTests {
  @Test
  func testTaskStateRawValues() {
    #expect(TaskState.blocked.rawValue == "blocked")
    #expect(TaskState.active.rawValue == "active")
    #expect(TaskState.done.rawValue == "done")
  }
}
