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
    self.references = references
    self.createdAt = createdAt
    self.updatedAt = updatedAt
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
    let uuidString = id.uuidString.replacingOccurrences(of: "-", with: "")
    let hexPrefix = String(uuidString.prefix(14)) // 54 bits = 13.5 hex chars, take 14

    var data = Data()
    for i in stride(from: 0, to: hexPrefix.count, by: 2) {
      let start = hexPrefix.index(hexPrefix.startIndex, offsetBy: i)
      let end = hexPrefix.index(start, offsetBy: 2, limitedBy: hexPrefix.endIndex) ?? hexPrefix.endIndex
      if let byte = UInt8(String(hexPrefix[start..<end]), radix: 16) {
        data.append(byte)
      }
    }

    let base64 = data.base64EncodedString()
      .replacingOccurrences(of: "=", with: "")
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
    return "T_\(base64.prefix(9))"
  }
}
