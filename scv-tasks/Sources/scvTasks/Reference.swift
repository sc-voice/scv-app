import Foundation
import UUIDV7

public struct Reference: Codable, Sendable, Identifiable {
  public let id: String
  public var text: String?
  public var url: URL?
  public var relevance: Double

  public init(
    id: String? = nil,
    text: String? = nil,
    url: URL? = nil,
    relevance: Double = 0.5
  ) {
    self.id = id ?? Task.uuidToBase64(UUIDV7())
    self.text = text
    self.url = url
    self.relevance = max(0, min(1, relevance))  // Clamp to 0...1
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? Task.uuidToBase64(UUIDV7())
    self.text = try container.decodeIfPresent(String.self, forKey: .text)
    self.url = try container.decodeIfPresent(URL.self, forKey: .url)
    let relevanceValue = try container.decodeIfPresent(Double.self, forKey: .relevance) ?? 0.5
    self.relevance = max(0, min(1, relevanceValue))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(text, forKey: .text)
    try container.encodeIfPresent(url, forKey: .url)
    try container.encode(relevance, forKey: .relevance)
  }

  enum CodingKeys: String, CodingKey {
    case id
    case text
    case url
    case relevance
  }
}

