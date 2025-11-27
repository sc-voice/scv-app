import Foundation

class AuthorInfoImporter {
  private let filePath: String
  private var cache: [String: [String: Any]]?

  init(filePath: String) {
    self.filePath = filePath
  }

  func getAuthorName(_ author: String) -> String {
    let dict = loadAuthorDict()
    return (dict[author]?["name"] as? String) ?? author
  }

  func getAuthorJSON(_ author: String) -> String? {
    let dict = loadAuthorDict()
    guard let authorInfo = dict[author] else { return nil }
    guard let jsonData = try? JSONSerialization
      .data(withJSONObject: authorInfo),
      let jsonStr = String(data: jsonData, encoding: .utf8)
    else {
      return nil
    }
    return jsonStr
  }

  private func loadAuthorDict() -> [String: [String: Any]] {
    if let cached = cache {
      return cached
    }

    var authorDict: [String: [String: Any]] = [:]
    if let authorData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
      if let dict = try? JSONSerialization
        .jsonObject(with: authorData) as? [String: [String: Any]]
      {
        authorDict = dict
      }
    }

    cache = authorDict
    return authorDict
  }
}
