import Foundation

public class WorldModel: @unchecked Sendable, Codable {
  public static let shared = WorldModel()

  public var taskStack: [TaskId]
  public var limit: Int
  public var verbosity: Int

  public init(taskStack: [TaskId] = [], limit: Int = 20, verbosity: Int = 1) {
    self.taskStack = taskStack
    self.limit = limit
    self.verbosity = max(0, min(2, verbosity))  // Clamp to 0-2
  }

  required public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.taskStack = try container.decodeIfPresent([TaskId].self, forKey: .taskStack) ?? []
    self.limit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? 20
    let verbosityValue = try container.decodeIfPresent(Int.self, forKey: .verbosity) ?? 1
    self.verbosity = max(0, min(2, verbosityValue))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(taskStack, forKey: .taskStack)
    try container.encode(limit, forKey: .limit)
    try container.encode(verbosity, forKey: .verbosity)
  }

  enum CodingKeys: String, CodingKey {
    case taskStack
    case limit
    case verbosity
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
