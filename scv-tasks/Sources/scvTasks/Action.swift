import Foundation

public struct Action: Codable, Identifiable, Sendable {
  public let id: UUID
  public var description: String
  public var taskId: String?

  public init(
    description: String,
    taskId: String? = nil,
    id: UUID = UUID(),
  ) {
    self.id = id
    self.description = description
    self.taskId = taskId
  }
}
