import CryptoKit
import Foundation
import UUIDV7

public struct Reference: Codable, Sendable, Identifiable {
  public var text: String?
  public var url: URL?
  public var relevance: Double

  // Computed id: first 4 chars of MD5 hash of text (if present) or url (if
  // present)
  public var id: String {
    let content = text ?? (url?.absoluteString ?? "")
    let data = content.data(using: .utf8) ?? Data()
    let digest = CryptoKit.Insecure.MD5.hash(data: data)
    let hex = digest.map { String(format: "%02x", $0) }.joined()
    return String(hex.prefix(4))
  }

  public init(
    text: String? = nil,
    url: URL? = nil,
    relevance: Double = 0.5,
  ) {
    self.text = text
    self.url = url
    self.relevance = max(0, min(1, relevance)) // Clamp to 0...1
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    text = try container.decodeIfPresent(String.self, forKey: .text)
    url = try container.decodeIfPresent(URL.self, forKey: .url)
    let relevanceValue = try container.decodeIfPresent(
      Double.self,
      forKey: .relevance,
    ) ?? 0.5
    relevance = max(0, min(1, relevanceValue))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(text, forKey: .text)
    try container.encodeIfPresent(url, forKey: .url)
    try container.encode(relevance, forKey: .relevance)
  }

  enum CodingKeys: String, CodingKey {
    case text
    case url
    case relevance
  }
}
