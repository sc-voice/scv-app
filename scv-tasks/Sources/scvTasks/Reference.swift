import Foundation

public enum Reference: Codable, Sendable {
  case filePath(String)
  case text(String)

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let filePath = try container.decodeIfPresent(String.self, forKey: .filePath) {
      self = .filePath(filePath)
    } else if let text = try container.decodeIfPresent(String.self, forKey: .text) {
      self = .text(text)
    } else {
      throw DecodingError.dataCorruptedError(
        forKey: .filePath,
        in: container,
        debugDescription: "Reference must have either filePath or text"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .filePath(let path):
      try container.encode(path, forKey: .filePath)
    case .text(let text):
      try container.encode(text, forKey: .text)
    }
  }

  enum CodingKeys: String, CodingKey {
    case filePath
    case text
  }
}
