import Foundation

public enum TaskState: String, Codable, Sendable {
  case blocked
  case active
  case done
}
