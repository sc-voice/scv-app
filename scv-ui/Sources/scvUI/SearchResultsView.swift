import scvCore
import SwiftUI

/// Displays search results as a list of sutta IDs and their relevance scores
public struct SearchResultsView: View {
  let results: [String]
  let query: String
  let language: String
  let author: String

  @State private var resultScores: [(suttaId: String, score: Double)] = []
  @State private var isLoading: Bool = true
  @State private var error: String? = nil

  public init(
    results: [String],
    query: String,
    language: String = "en",
    author: String = "sujato",
  ) {
    self.results = results
    self.query = query
    self.language = language
    self.author = author
  }

  public var body: some View {
    VStack(spacing: 0) {
      // Header
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Search Results")
              .font(.headline)
            Text("Query: \(query)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          Spacer()
          Text("\(results.count) results")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
      }
      .background(Color(.systemGray6))

      // Results List
      if isLoading {
        VStack(spacing: 12) {
          ProgressView()
          Text("Loading scores...")
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error {
        VStack(spacing: 8) {
          Image(systemName: "exclamationmark.circle")
            .font(.title2)
            .foregroundColor(.red)
          Text("Error")
            .font(.headline)
          Text(error)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
      } else if resultScores.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "magnifyingglass")
            .font(.title2)
            .foregroundColor(.secondary)
          Text("No results found")
            .font(.headline)
          Text("Try adjusting your search query")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          ForEach(resultScores, id: \.suttaId) { result in
            VStack(alignment: .leading, spacing: 4) {
              Text(result.suttaId)
                .font(.body)
                .fontWeight(.semibold)
              Text(String(format: "Relevance: %.1f%%", result.score * 100))
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .task {
      await loadScores()
    }
  }

  private func loadScores() async {
    isLoading = true
    error = nil

    let scoresWithDetails = await EbtData.shared.searchKeywordsWithScores(
      lang: language,
      author: author,
      query: query,
    )

    resultScores = scoresWithDetails.map { (suttaId: $0.key, score: $0.score) }
    isLoading = false
  }
}

#if DEBUG
  struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
      SearchResultsView(
        results: ["mn1", "mn2", "dn1"],
        query: "root of suffering",
        language: "en",
        author: "sujato",
      )
    }
  }
#endif
