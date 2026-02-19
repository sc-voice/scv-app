#!/usr/bin/env swift

import Foundation

struct LocalizationEntry {
  let comment: String
  let key: String
  let value: String

  var formatted: String {
    var result = ""
    if !comment.isEmpty {
      result += "/* \(comment) */\n"
    }
    result += "\"\(key)\" = \"\(value)\";"
    return result
  }
}

func parseLocalizableStrings(filePath: String) -> [LocalizationEntry] {
  guard let content = try? String(contentsOfFile: filePath, encoding: .utf8)
  else {
    print("Error: Could not read file \(filePath)")
    return []
  }

  var entries: [LocalizationEntry] = []
  let lines = content.components(separatedBy: .newlines)

  var i = 0
  while i < lines.count {
    let line = lines[i].trimmingCharacters(in: .whitespaces)

    // Look for comment
    var comment = ""
    if line.hasPrefix("/*"), line.hasSuffix("*/") {
      comment = String(line.dropFirst(2).dropLast(2))
        .trimmingCharacters(in: .whitespaces)
      i += 1

      // Skip empty lines between comment and entry
      while i < lines.count,
            lines[i].trimmingCharacters(in: .whitespaces).isEmpty
      {
        i += 1
      }
    }

    // Look for key-value pair
    if i < lines.count {
      let entryLine = lines[i].trimmingCharacters(in: .whitespaces)
      if entryLine.hasPrefix("\"") {
        if let entry = parseEntry(entryLine) {
          entries.append(LocalizationEntry(
            comment: comment,
            key: entry.key,
            value: entry.value,
          ))
        }
        i += 1
      } else {
        i += 1
      }
    }

    // Skip empty lines
    while i < lines.count,
          lines[i].trimmingCharacters(in: .whitespaces).isEmpty
    {
      i += 1
    }
  }

  return entries
}

func parseEntry(_ line: String) -> (key: String, value: String)? {
  // Format: "key" = "value";
  guard let equalsIndex = line.firstIndex(of: "=") else { return nil }

  let keyPart = String(line[..<equalsIndex])
    .trimmingCharacters(in: .whitespaces)
  let valuePart = String(line[line.index(after: equalsIndex)...])
    .trimmingCharacters(in: .whitespaces)

  // Extract key (remove quotes)
  let key = keyPart.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

  // Extract value (remove quotes and semicolon)
  let value = valuePart
    .trimmingCharacters(in: CharacterSet(charactersIn: "\";"))
    .trimmingCharacters(in: .whitespaces)

  return (key, value)
}

func writeLocalizableStrings(filePath: String, entries: [LocalizationEntry]) {
  var output = ""
  for (index, entry) in entries.enumerated() {
    output += entry.formatted
    if index < entries.count - 1 {
      output += "\n\n"
    }
  }
  output += "\n"

  do {
    try output.write(toFile: filePath, atomically: true, encoding: .utf8)
    print("✓ Sorted \(filePath) (\(entries.count) entries)")
  } catch {
    print("Error: Could not write to file \(filePath): \(error)")
  }
}

// Main
let localizableFilePaths = [
  "/Users/visakha/dev/scv-app/scv-core/Sources/Resources/en.lproj/Localizable.strings",
  "/Users/visakha/dev/scv-app/scv-core/Sources/Resources/fr.lproj/Localizable.strings",
  "/Users/visakha/dev/scv-app/scv-core/Sources/Resources/es.lproj/Localizable.strings",
  "/Users/visakha/dev/scv-app/scv-core/Sources/Resources/pt-PT.lproj/Localizable.strings",
  "/Users/visakha/dev/scv-app/scv-core/Sources/Resources/ru.lproj/Localizable.strings",
  "/Users/visakha/dev/scv-app/scv-core/Sources/Resources/lt.lproj/Localizable.strings",
  "/Users/visakha/dev/scv-app/scv-core/Sources/Resources/de.lproj/Localizable.strings",
]

for filePath in localizableFilePaths {
  var entries = parseLocalizableStrings(filePath: filePath)
  entries.sort { $0.key < $1.key }
  writeLocalizableStrings(filePath: filePath, entries: entries)
}

print("\n✓ All localization files sorted alphabetically")
