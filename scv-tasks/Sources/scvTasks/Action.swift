import Foundation
import UUIDV7

public struct Action: Codable, Identifiable, Sendable {
  public let id: String?
  public var name: String?
  public var description: String
  public var complexity: String?
  public var duration: TimeInterval?

  public init(
    description: String,
    name: String? = nil,
    id: String? = Task.shortId(),
    complexity: String? = nil,
    duration: TimeInterval? = nil,
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.complexity = complexity
    self.duration = duration
  }
}
