import Foundation

public class WorldModel: @unchecked Sendable, Codable {
  public static let shared = WorldModel()

  public var taskStack: [TaskId]

  public init(taskStack: [TaskId] = []) {
    self.taskStack = taskStack
  }

  public func pushTask(_ taskId: TaskId) {
    taskStack.append(taskId)
  }

  public func popTask() -> TaskId? {
    taskStack.popLast()
  }

  public func currentTask() -> TaskId? {
    taskStack.last
  }

  public func clearStack() {
    taskStack.removeAll()
  }

  public func save(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(self)
    try data.write(to: url)
  }

  public static func load(from url: URL) throws -> WorldModel {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let data = try Data(contentsOf: url)
    return try decoder.decode(WorldModel.self, from: data)
  }
}
