import Foundation
import scvCore

// Count Pali words in mn44/en/sujato
let outputPath = "/Users/visakha/dev/scv-app/local/build/pali-en-mn44.json"

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

func main() async {
  do {
    guard let suttaRef = SuttaRef.create("mn44/en/sujato") else {
      print("Error: Invalid sutta reference")
      exit(1)
    }

    let counter = PaliWords(lang: "en")
    await counter.countPaliWords(suttaRef: suttaRef)

    // Get MLDocument to print segments with "iti"
    guard let mlDoc = await EbtData.getMLDocument(suttaRef: suttaRef) else {
      print("Error: Could not load document")
      exit(1)
    }

    printSegmentsWithWord("iti", in: mlDoc)

    print("Sutta: mn44/en/sujato")
    print("Pali words in paliDict: \(counter.paliDict.count)")
    print("Unique pali words found in English: \(counter.docPaliDict.count)")
    print("Total pali word occurrences: \(counter.paliWords)")

    // Create output JSON with docPaliDict entries
    let output: [String: Any] = [
      "sutta": "mn44",
      "lang": "en",
      "author": "sujato",
      "pali_dict_count": counter.paliDict.count,
      "unique_pali_words_found": counter.docPaliDict.count,
      "total_pali_word_occurrences": counter.paliWords,
      "pali_words": counter.docPaliDict,
    ]

    let outputData = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)

    // Create output directory if needed
    try FileManager.default.createDirectory(
      atPath: "/Users/visakha/dev/scv-app/local/build",
      withIntermediateDirectories: true
    )

    // Write output file
    try outputData.write(to: URL(fileURLWithPath: outputPath))
    print("Output written to: \(outputPath)")

    if let json = String(data: outputData, encoding: .utf8) {
      print("\n\(json)")
    }
  } catch {
    print("Error: \(error)")
    exit(1)
  }
}

await main()
