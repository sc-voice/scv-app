import Foundation

public enum TaskState: String, Codable, Sendable {
  case blocked
  case pending
  case active
  case done
}
