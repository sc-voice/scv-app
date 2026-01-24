import Foundation
import UUIDV7

public struct Task: Codable, Identifiable, Sendable {
  public let id: UUIDV7
  public var name: String
  public var summary: String
  public var state: TaskState
  public var requiredTasks: [UUIDV7]
  public var plannedActions: [Action]
  public var completedActions: [Action]
  public var references: [Reference]
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUIDV7 = UUIDV7(),
    name: String,
    summary: String,
    state: TaskState = .active,
    requiredTasks: [UUIDV7] = [],
    plannedActions: [Action] = [],
    completedActions: [Action] = [],
    references: [Reference] = [],
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.summary = summary
    self.state = state
    self.requiredTasks = requiredTasks
    self.plannedActions = plannedActions
    self.completedActions = completedActions
    self.references = references.sorted { a, b in
      if a.relevance != b.relevance {
        return a.relevance > b.relevance  // Decreasing relevance
      }
      return a.id < b.id  // Tiebreaker: id comparison
    }
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUIDV7.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.summary = try container.decode(String.self, forKey: .summary)
    self.state = try container.decode(TaskState.self, forKey: .state)
    self.requiredTasks = try container.decodeIfPresent([UUIDV7].self, forKey: .requiredTasks) ?? []
    self.plannedActions = try container.decodeIfPresent([Action].self, forKey: .plannedActions) ?? []
    self.completedActions = try container.decodeIfPresent([Action].self, forKey: .completedActions) ?? []
    var refs = try container.decodeIfPresent([Reference].self, forKey: .references) ?? []
    // Sort references by decreasing relevance, then by id
    refs.sort { a, b in
      if a.relevance != b.relevance {
        return a.relevance > b.relevance
      }
      return a.id < b.id
    }
    self.references = refs
    self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case summary
    case state
    case requiredTasks
    case plannedActions
    case completedActions
    case references
    case createdAt
    case updatedAt
  }

  public mutating func moveActionToCompleted(at index: Int) {
    guard index < plannedActions.count else { return }
    let action = plannedActions.remove(at: index)
    completedActions.append(action)
    updatedAt = Date()
  }

  public mutating func addPlannedAction(_ action: Action) {
    plannedActions.append(action)
    updatedAt = Date()
  }

  public mutating func updateState(_ newState: TaskState) {
    state = newState
    updatedAt = Date()
  }

  public var isBlocked: Bool {
    state == .blocked
  }

  public var isActive: Bool {
    state == .active
  }

  public var isDone: Bool {
    state == .done
  }

  public var fileName: String {
    // Extract first 54 bits and encode to URL-safe base64 (9 chars)
    let base64 = Task.uuidToBase64(id)
    return "T_\(base64.prefix(9))"
  }

  // Convert UUIDV7 to URL-safe base64 string (full 24 chars)
  public static func uuidToBase64(_ uuid: UUIDV7) -> String {
    let uuidString = uuid.uuidString.replacingOccurrences(of: "-", with: "")

    var data = Data()
    for i in stride(from: 0, to: uuidString.count, by: 2) {
      let start = uuidString.index(uuidString.startIndex, offsetBy: i)
      let end = uuidString.index(start, offsetBy: 2, limitedBy: uuidString.endIndex) ?? uuidString.endIndex
      if let byte = UInt8(String(uuidString[start..<end]), radix: 16) {
        data.append(byte)
      }
    }

    return data.base64EncodedString()
      .replacingOccurrences(of: "=", with: "")
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
  }
}
