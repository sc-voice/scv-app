import CryptoKit
import Foundation
import UUIDV7

public struct Action: Codable, Identifiable, Sendable {
  public var name: String
  public var description: String?
  public var complexity: String?
  public var duration: TimeInterval?
  public var test: String?

  // Reference to world (not encoded, not stored in JSON)
  public var taskWorld: ITaskWorld?

  // Computed id: first 4 chars of MD5 hash of name
  public var id: String {
    let data = name.data(using: .utf8) ?? Data()
    let digest = CryptoKit.Insecure.MD5.hash(data: data)
    let hex = digest.map { String(format: "%02x", $0) }.joined()
    return String(hex.prefix(4))
  }

  public init(
    name: String,
    description: String? = nil,
    complexity: String? = nil,
    duration: TimeInterval? = nil,
    test: String? = nil,
    taskWorld: ITaskWorld? = nil,
  ) {
    self.name = name
    self.description = description
    self.complexity = complexity
    self.duration = duration
    self.taskWorld = taskWorld
    // Use provided test value, or fall back to world.testDefault, or TaskWorld.TEST_DEFAULT
    self.test = test ?? taskWorld?.testDefault ?? TaskWorld.TEST_DEFAULT
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Handle migration: if name is missing, try to use description as name
    if let decodedName = try container.decodeIfPresent(String.self, forKey: .name) {
      name = decodedName
      description = try container.decodeIfPresent(String.self, forKey: .description)
    } else if let decodedDescription = try container.decodeIfPresent(String.self, forKey: .description) {
      // Migration: old format had description as primary, now name is primary
      name = decodedDescription
      description = nil
    } else {
      throw DecodingError.keyNotFound(CodingKeys.name, DecodingError.Context(
        codingPath: container.codingPath,
        debugDescription: "Action requires either 'name' or 'description' field"
      ))
    }
    complexity = try container.decodeIfPresent(String.self, forKey: .complexity)
    duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
    let decodedTest = try container.decodeIfPresent(String.self, forKey: .test)

    // Get taskWorld from decoder userInfo
    if let key = CodingUserInfoKey(rawValue: "taskWorld"),
       let world = decoder.userInfo[key] as? ITaskWorld
    {
      taskWorld = world
    } else {
      taskWorld = nil
    }

    // Use decoded value, or fall back to world.testDefault, or TaskWorld.TEST_DEFAULT
    test = decodedTest ?? taskWorld?.testDefault ?? TaskWorld.TEST_DEFAULT
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(complexity, forKey: .complexity)
    try container.encodeIfPresent(duration, forKey: .duration)
    try container.encodeIfPresent(test, forKey: .test)
  }

  enum CodingKeys: String, CodingKey {
    case name
    case description
    case complexity
    case duration
    case test
  }
}
