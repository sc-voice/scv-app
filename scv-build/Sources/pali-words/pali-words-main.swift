import Foundation
import scvCore

let cc = ColorConsole(#file, #function, dbg.EbtData.other)

enum PaliWordsError: Error {
  case noCommandProvided
  case invalidCommand(String)
  case invalidSuttaRef(String)
  case invalidLanguage(String)
  case documentLoadFailed
}

enum Command {
  case countSuttaPali(suttaRef: String)
  case countDocPali(lang: String)
}

func parseArguments(_ args: [String]) throws -> Command {
  guard args.count >= 2 else {
    throw PaliWordsError.noCommandProvided
  }

  let command = args[0]
  let argument = args[1]

  switch command {
  case "--count-sutta-pali":
    return .countSuttaPali(suttaRef: argument)
  case "--count-doc-pali":
    return .countDocPali(lang: argument)
  default:
    throw PaliWordsError.invalidCommand(command)
  }
}

func printSegmentsWithWord(_ word: String, in mlDoc: MLDocument) {
  print("\n=== Segments containing '\(word)' ===\n")
  for segment in mlDoc.segments() {
    if let doc = segment.doc, doc.lowercased().contains(word) {
      print("Segment: \(segment.scid)")
      print("Doc: \(doc)")
      print("Pli: \(segment.pli ?? "N/A")")
      print("---")
    }
  }
}

func countSuttaPali(suttaRef: String) async throws {
  guard let suttaRef = SuttaRef.create(suttaRef) else {
    throw PaliWordsError.invalidSuttaRef(suttaRef)
  }

  let counter = PaliWords(lang: suttaRef.lang)
  await counter.countPaliWords(suttaRef: suttaRef)

  // Get MLDocument to print segments with "iti"
  guard let mlDoc = await EbtData.getMLDocument(suttaRef: suttaRef) else {
    throw PaliWordsError.documentLoadFailed
  }

  printSegmentsWithWord("iti", in: mlDoc)

  print("Sutta: \(suttaRef)")
  print("Pali words in paliDict: \(counter.paliDict.count)")
  print("Unique pali words found in \(suttaRef.lang): \(counter.docPaliDict.count)")
  print("Total pali word occurrences: \(counter.paliWords)")

  // Create output JSON with docPaliDict entries
  let output: [String: Any] = [
    "sutta": suttaRef.suttaUid,
    "lang": suttaRef.lang,
    "author": suttaRef.author ?? "",
    "pali_dict_count": counter.paliDict.count,
    "unique_pali_words_found": counter.docPaliDict.count,
    "total_pali_word_occurrences": counter.paliWords,
    "pali_words": counter.docPaliDict,
  ]

  let outputData = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)

  // Create output directory if needed
  let buildDir = "/Users/visakha/dev/scv-app/local/build"
  try FileManager.default.createDirectory(
    atPath: buildDir,
    withIntermediateDirectories: true
  )

  // Write output file
  let outputPath = "\(buildDir)/pali-\(suttaRef.lang)-\(suttaRef.suttaUid).json"
  try outputData.write(to: URL(fileURLWithPath: outputPath))
  print("Output written to: \(outputPath)")

  if let json = String(data: outputData, encoding: .utf8) {
    print("\n\(json)")
  }
}

func countDocPali(lang: String) async throws {
  let counter = PaliWords(lang: lang)
  var processedCount = 0
  var totalSuttas = 0

  // Get all available authors
  let authors = await EbtData.shared.availableAuthors()
  let langAuthors = authors.filter { $0.lang == lang }

  guard !langAuthors.isEmpty else {
    throw PaliWordsError.invalidLanguage(lang)
  }

  print("Processing \(lang) translations from \(langAuthors.count) author(s)...")

  for (_, author) in langAuthors {
    let suttaUids = await EbtData.shared.suttaUidsForAuthor(lang: lang, author: author)
    totalSuttas += suttaUids.count

    for suttaUid in suttaUids {
      guard let suttaRef = SuttaRef.create("\(suttaUid)/\(lang)/\(author)") else {
        continue
      }

      await counter.countPaliWords(suttaRef: suttaRef)
      processedCount += 1
      cc.ok1(#line, "\(suttaRef.suttaUid) [\(processedCount)/\(totalSuttas)]")
    }
  }

  print("\nProcessing complete!")
  print("Processed suttas: \(processedCount)")
  print("Unique pali words found in \(lang): \(counter.docPaliDict.count)")
  print("Total pali word occurrences: \(counter.paliWords)")

  // Sort docPaliDict by count (descending) and write JSONL
  let sortedWords = counter.docPaliDict.sorted { $0.value > $1.value }

  let resourcesDir = "/Users/visakha/dev/scv-app/scv-build/Sources/Resources"
  try FileManager.default.createDirectory(
    atPath: resourcesDir,
    withIntermediateDirectories: true
  )

  let outputPath = "\(resourcesDir)/pali-\(lang).json"

  // Create or truncate file
  FileManager.default.createFile(atPath: outputPath, contents: nil, attributes: nil)
  let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: outputPath))

  for (word, count) in sortedWords {
    let entry: [String: Any] = [word: count]
    let jsonData = try JSONSerialization.data(withJSONObject: entry, options: [])
    if let jsonString = String(data: jsonData, encoding: .utf8) {
      fileHandle.write((jsonString + "\n").data(using: .utf8)!)
    }
  }

  fileHandle.closeFile()
  print("Output written to: \(outputPath)")
}

func main() async {
  do {
    let args = Array(CommandLine.arguments.dropFirst())

    guard !args.isEmpty else {
      print("Usage:")
      print("  pali-words --count-sutta-pali SUTTA_REF    Count pali words for single sutta")
      print("  pali-words --count-doc-pali LANG           Count pali words for all suttas in language")
      print("")
      print("Examples:")
      print("  pali-words --count-sutta-pali mn44/en/sujato")
      print("  pali-words --count-doc-pali en")
      exit(0)
    }

    let command = try parseArguments(args)

    switch command {
    case let .countSuttaPali(suttaRef):
      try await countSuttaPali(suttaRef: suttaRef)
    case let .countDocPali(lang):
      try await countDocPali(lang: lang)
    }
  } catch {
    print("Error: \(error)")
    exit(1)
  }
}

await main()
