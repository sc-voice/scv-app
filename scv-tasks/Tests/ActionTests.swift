import Foundation
@testable import scvTasks
import Testing
import UUIDV7

struct ActionTests {
  @Test
  func actionDefault() throws {
    let name = "aName"
    let action = Action(
      name: name,
    )
    // id is computed from name hash, first 4 hex chars
    #expect(action.id.count == 4)
    #expect(action.name == name)
    #expect(action.description == nil)
    #expect(action.complexity == nil)
    #expect(action.duration == nil)
    // test defaults to TaskWorld.TEST_DEFAULT when no taskWorld provided
    #expect(action.test == TaskWorld.TEST_DEFAULT)

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
    let name = "aName"
    let description = "aDescription"
    let complexity = "aComplexity"
    let duration = TimeInterval(123)
    let action = Action(
      name: name,
      description: description,
      complexity: complexity,
      duration: duration,
    )
    // id is computed from name hash (name is always present)
    #expect(action.id.count == 4)
    #expect(action.name == name)
    #expect(action.description == description)
    #expect(action.complexity == complexity)
    #expect(action.duration == duration)
    #expect(action.test == TaskWorld.TEST_DEFAULT)

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
