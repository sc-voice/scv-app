import Foundation
@testable import scvTasks
import Testing
import UUIDV7

struct ActionTests {
  @Test
  func actionDefault() throws {
    let description = "aDescription"
    let action = Action(
      description: description,
    )
    #expect(action.id != nil)
    #expect(action.id!.count == 8)
    #expect(action.name == nil)
    #expect(action.description == description)
    #expect(action.complexity == nil)
    #expect(action.duration == nil)

    let encoder = JSONEncoder()
    let data = try encoder.encode(action)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Action.self, from: data)
    #expect(decoded.id == action.id)
    #expect(decoded.name == action.name)
    #expect(decoded.description == action.description)
    #expect(decoded.complexity == action.complexity)
    #expect(decoded.duration == action.duration)
  }

  @Test
  func actionCreation() throws {
    let id = "aId"
    let name = "aName"
    let description = "aDescription"
    let complexity = "aComplexity"
    let duration = TimeInterval(123)
    let action = Action(
      description: description,
      name: name,
      id: id,
      complexity: complexity,
      duration: duration,
    )
    #expect(action.id == id)
    #expect(action.name == name)
    #expect(action.description == description)
    #expect(action.complexity == complexity)
    #expect(action.duration == duration)

    let encoder = JSONEncoder()
    let data = try encoder.encode(action)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(Action.self, from: data)
    #expect(decoded.id == action.id)
    #expect(decoded.name == action.name)
    #expect(decoded.description == action.description)
    #expect(decoded.complexity == action.complexity)
    #expect(decoded.duration == action.duration)
  }
}
