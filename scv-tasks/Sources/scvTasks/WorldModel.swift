import Foundation

public class WorldModel: @unchecked Sendable, Codable {
  public static let shared = WorldModel()

  public var taskStack: [TaskId]
  public var limit: Int
  public var verbosity: Int
  public var lineLength: Int
  public var showDone: Bool
  public var showUpdate: Bool

  public init(taskStack: [TaskId] = [], limit: Int = 20, verbosity: Int = 1, lineLength: Int = 80, showDone: Bool = false, showUpdate: Bool = false) {
    self.taskStack = taskStack
    self.limit = limit
    self.verbosity = max(0, min(2, verbosity)) // Clamp to 0-2
    self.lineLength = max(20, lineLength) // Minimum 20 chars
    self.showDone = showDone
    self.showUpdate = showUpdate
  }

  public required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    taskStack = try container.decodeIfPresent(
      [TaskId].self,
      forKey: .taskStack,
    ) ?? []
    limit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? 20
    let verbosityValue = try container.decodeIfPresent(
      Int.self,
      forKey: .verbosity,
    ) ?? 1
    verbosity = max(0, min(2, verbosityValue))
    let lineLengthValue = try container.decodeIfPresent(Int.self, forKey: .lineLength) ?? 80
    lineLength = max(20, lineLengthValue)
    showDone = try container.decodeIfPresent(Bool.self, forKey: .showDone) ?? false
    showUpdate = try container.decodeIfPresent(Bool.self, forKey: .showUpdate) ?? false
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(taskStack, forKey: .taskStack)
    try container.encode(limit, forKey: .limit)
    try container.encode(verbosity, forKey: .verbosity)
    try container.encode(lineLength, forKey: .lineLength)
    try container.encode(showDone, forKey: .showDone)
    try container.encode(showUpdate, forKey: .showUpdate)
  }

  enum CodingKeys: String, CodingKey {
    case taskStack
    case limit
    case verbosity
    case lineLength
    case showDone
    case showUpdate
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
