import Foundation
import UUIDV7

// MARK: - TaskCreationError

public enum TaskCreationError: Error {
  case filenameTaken(String)
}

// Helper to decode either UUID or String from JSON
struct AnyCodableTaskId: Codable {
  let uuidV7Value: UUIDV7?
  let stringValue: String?

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    // Try UUID first
    if let uuid = try? container.decode(UUIDV7.self) {
      uuidV7Value = uuid
      stringValue = nil
    } else if let str = try? container.decode(String.self) {
      uuidV7Value = nil
      stringValue = str
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected UUID or String"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    if let uuid = uuidV7Value {
      try container.encode(uuid)
    } else if let str = stringValue {
      try container.encode(str)
    }
  }
}

public struct Task: Codable, Identifiable, Sendable {
  // TODO: Review Sendable compliance. taskWorld property holds ITaskWorld reference which may not be Sendable.
  // May need @unchecked Sendable or refactor taskWorld access pattern.

  public let uuid: UUIDV7
  public let idFile: String  // Computed from uuid at init, stored for convenience
  public var name: String
  public var summary: String
  public var requiredTasks: [AnyTaskId]
  public var plannedActions: [Action]
  public var completedActions: [Action]
  public var references: [Reference]
  public var createdAt: Date
  public var updatedAt: Date

  // Reference to world (not encoded, not stored in JSON)
  public var taskWorld: ITaskWorld?

  // Computed state based on requiredTasks and stack membership
  public var state: TaskState {
    guard let world = taskWorld else { return .pending }

    // Blocked if any required task is not done
    for requiredId in requiredTasks {
      if let requiredTask = world.taskFrom(anyId: requiredId), requiredTask.state != .done {
        return .blocked
      }
    }

    // Active if on stack, otherwise pending
    return world.isStackTaskId(idFile) ? .active : .pending
  }

  // For Identifiable protocol
  public var id: UUIDV7 {
    uuid
  }

  private init(
    uuid: UUIDV7,
    name: String,
    summary: String,
    requiredTasks: [AnyTaskId] = [],
    plannedActions: [Action] = [],
    completedActions: [Action] = [],
    references: [Reference] = [],
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    taskWorld: ITaskWorld? = nil
  ) {
    self.uuid = uuid
    self.idFile = Task.uuidToFilename(uuid)
    self.name = name
    self.summary = summary
    self.requiredTasks = requiredTasks
    self.plannedActions = plannedActions
    self.completedActions = completedActions
    self.references = references.sorted { a, b in
      if a.relevance != b.relevance {
        return a.relevance > b.relevance // Decreasing relevance
      }
      return a.id < b.id // Tiebreaker: id comparison
    }
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.taskWorld = taskWorld
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    uuid = try container.decode(UUIDV7.self, forKey: .uuid)
    idFile = Task.uuidToFilename(uuid)
    name = try container.decode(String.self, forKey: .name)
    summary = try container.decode(String.self, forKey: .summary)

    // Handle requiredTasks: accept both UUIDV7 and filename string formats
    var requiredTasksResult: [AnyTaskId] = []
    if let container = try container.decodeIfPresent(
      [AnyCodableTaskId].self,
      forKey: .requiredTasks
    ) {
      for item in container {
        if let uuid = item.uuidV7Value {
          requiredTasksResult.append(uuid.uuidString)
        } else if let str = item.stringValue {
          requiredTasksResult.append(str)
        }
      }
    }
    requiredTasks = requiredTasksResult

    plannedActions = try container.decodeIfPresent(
      [Action].self,
      forKey: .plannedActions,
    ) ?? []
    completedActions = try container.decodeIfPresent(
      [Action].self,
      forKey: .completedActions,
    ) ?? []
    var refs = try container.decodeIfPresent(
      [Reference].self,
      forKey: .references,
    ) ?? []
    // Sort references by decreasing relevance, then by id
    refs.sort { a, b in
      if a.relevance != b.relevance {
        return a.relevance > b.relevance
      }
      return a.id < b.id
    }
    references = refs
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)

    // Get taskWorld from decoder userInfo
    if let key = CodingUserInfoKey(rawValue: "taskWorld"),
       let world = decoder.userInfo[key] as? ITaskWorld {
      taskWorld = world
    } else {
      taskWorld = nil
    }
  }

  // MARK: - Factory Method (Internal)

  /// Create a new Task with guaranteed unique filename by checking against taskWorld.
  /// Throws if filename collision detected.
  /// Called by ITaskWorld.createTask() to ensure filename uniqueness.
  ///
  /// - Parameters:
  ///   - world: The TaskWorld to check for filename uniqueness
  ///   - uuid: The UUID for the task (default: new monotonic UUIDV7). Tests can pass deterministic UUIDs.
  ///   - name: Task name (default: empty string, can be updated later)
  ///   - summary: Task summary (default: empty string, can be updated later)
  /// - Throws: TaskCreationError.filenameTaken if filename already exists
  static func create(
    world: ITaskWorld,
    uuid: UUIDV7 = UUIDV7(),
    name: String = "",
    summary: String = ""
  ) throws -> Task {
    let filename = Task.uuidToFilename(uuid)

    // Check if filename already exists in world
    guard world.taskFrom(anyId: filename) == nil else {
      throw TaskCreationError.filenameTaken(filename)
    }

    return Task(
      uuid: uuid,
      name: name,
      summary: summary,
      requiredTasks: [],
      plannedActions: [],
      completedActions: [],
      references: [],
      createdAt: Date(),
      updatedAt: Date(),
      taskWorld: world
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(uuid, forKey: .uuid)
    try container.encode(name, forKey: .name)
    try container.encode(summary, forKey: .summary)
    try container.encode(requiredTasks, forKey: .requiredTasks)
    try container.encode(plannedActions, forKey: .plannedActions)
    try container.encode(completedActions, forKey: .completedActions)
    try container.encode(references, forKey: .references)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(updatedAt, forKey: .updatedAt)
    // Note: state and taskWorld are NOT encoded (state is computed, taskWorld is context)
  }

  enum CodingKeys: String, CodingKey {
    case uuid = "id"  // JSON uses "id" field
    case name
    case summary
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

  public var isBlocked: Bool {
    state == .blocked
  }

  public var isActive: Bool {
    state == .active
  }

  public var isDone: Bool {
    state == .done
  }

  // Convert UUIDV7 to filename (e.g., "T_AZvuCKoac")
  public static func uuidToFilename(_ uuid: UUIDV7) -> String {
    let base64 = uuidToBase64(uuid)
    return "T_\(base64.prefix(9))"
  }

  // Convert UUIDV7 to URL-safe base64 string (full 24 chars)
  public static func uuidToBase64(_ uuid: UUIDV7) -> String {
    let uuidString = uuid.uuidString.replacingOccurrences(of: "-", with: "")

    var data = Data()
    for i in stride(from: 0, to: uuidString.count, by: 2) {
      let start = uuidString.index(uuidString.startIndex, offsetBy: i)
      let end = uuidString.index(
        start,
        offsetBy: 2,
        limitedBy: uuidString.endIndex,
      ) ?? uuidString.endIndex
      if let byte = UInt8(String(uuidString[start ..< end]), radix: 16) {
        data.append(byte)
      }
    }

    return data.base64EncodedString()
      .replacingOccurrences(of: "=", with: "")
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
  }
}
