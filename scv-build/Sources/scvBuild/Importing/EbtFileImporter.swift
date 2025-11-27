import Foundation

class EbtFileImporter {
  let language: String
  let author: String
  let translationDir: String

  init(language: String, author: String, translationDir: String) {
    self.language = language
    self.author = author
    self.translationDir = translationDir
  }

  func findTranslationFiles() throws -> [String] {
    var files: [String] = []

    let docDirs = ["sutta", "vinaya"]
    for docDir in docDirs {
      let docPath = "\(translationDir)/\(language)/\(author)/\(docDir)"
      if FileManager.default.fileExists(atPath: docPath) {
        let jsonFiles = findJSONFiles(inDirectory: docPath)
        files.append(contentsOf: jsonFiles)
      }
    }

    return files
  }

  func importFile(_ filePath: String) throws -> [String: String] {
    guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: filePath))
    else {
      throw ImportError.cannotReadFile(filePath)
    }

    guard let jsonObject = try? JSONSerialization
      .jsonObject(with: jsonData) as? [String: Any]
    else {
      throw ImportError.invalidJSON(filePath)
    }

    var segments: [String: String] = [:]
    for (segmentId, value) in jsonObject {
      let segmentText: String
      if let stringValue = value as? String {
        segmentText = stringValue
      } else if let numberValue = value as? NSNumber {
        segmentText = numberValue.stringValue
      } else {
        continue
      }
      segments[segmentId] = segmentText
    }

    return segments
  }

  private func findJSONFiles(inDirectory dir: String) -> [String] {
    var files: [String] = []
    guard let contents = try? FileManager.default
      .contentsOfDirectory(atPath: dir)
    else {
      return files
    }

    for item in contents {
      let itemPath = "\(dir)/\(item)"
      var isDir: ObjCBool = false
      if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir) {
        if isDir.boolValue {
          files.append(contentsOf: findJSONFiles(inDirectory: itemPath))
        } else if item.hasSuffix(".json") {
          files.append(itemPath)
        }
      }
    }
    return files
  }
}

enum ImportError: Error {
  case cannotReadFile(String)
  case invalidJSON(String)
}
