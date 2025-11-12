import scvCore
import SwiftUI

/// Test helper view that allows developers to easily test SearchSuttasIntent
/// Place in a debug/test section of the app or use in preview
#if DEBUG
  public struct SearchSuttasIntentTestHelper: View {
    @State private var testQuery: String = "root of suffering"
    @State private var searchResults: [String] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?
    @State private var showResults: Bool = false

    public init() {}

    public var body: some View {
      VStack(spacing: 16) {
        Text("SearchSuttasIntent Test Helper")
          .font(.headline)

        VStack(alignment: .leading, spacing: 8) {
          Text("Search Query")
            .font(.caption)
            .foregroundColor(.secondary)

          TextField("Enter search query", text: $testQuery)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled(true)

          HStack(spacing: 8) {
            Button(action: performSearch) {
              if isSearching {
                ProgressView()
                  .scaleEffect(0.8, anchor: .center)
              } else {
                Text("Search")
              }
            }
            .disabled(testQuery.isEmpty || isSearching)

            Button(action: clearResults) {
              Text("Clear")
            }
          }
          .font(.subheadline)
        }

        if let error = errorMessage {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              Image(systemName: "exclamationmark.circle")
                .foregroundColor(.red)
              Text("Error")
                .font(.caption)
                .fontWeight(.semibold)
            }
            Text(error)
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 8)
          .padding(.horizontal, 8)
          .background(Color(.systemRed).opacity(0.1))
          .cornerRadius(6)
        }

        if !searchResults.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Results (\(searchResults.count))")
              .font(.caption)
              .fontWeight(.semibold)

            List {
              ForEach(searchResults, id: \.self) { suttaId in
                Text(suttaId)
                  .font(.caption)
              }
            }
            .frame(maxHeight: 200)
            .listStyle(.insetGrouped)
          }
        }

        Spacer()
      }
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func performSearch() {
      isSearching = true
      errorMessage = nil

      Task {
        let language = Settings.shared.docLang.code
        let author = "sujato"

        let results = await EbtData.shared.searchKeywords(
          lang: language,
          author: author,
          query: testQuery
        )

        await MainActor.run {
          searchResults = results
          isSearching = false
          showResults = true
        }
      }
    }

    private func clearResults() {
      searchResults = []
      errorMessage = nil
      testQuery = ""
    }
  }

  #if DEBUG
    struct SearchSuttasIntentTestHelper_Previews: PreviewProvider {
      static var previews: some View {
        SearchSuttasIntentTestHelper()
      }
    }
  #endif
#endif
