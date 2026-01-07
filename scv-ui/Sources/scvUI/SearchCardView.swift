//
//  SearchCardView.swift
//  scv-ui
//
//  Created by Claude on 2025-11-18.
//

import scvCore
import SwiftUI

// MARK: - Quote HTML Parsing

/// AppFocus enum for tracking which result has focus
private enum AppFocus: Hashable {
  case none
  case resultRow(id: String)
  case segment(id: String)
  case sidebar(id: String)
  case search
}

/// Helper for parsing HTML quotes and converting to AttributedString
public enum QuoteHTMLParser {
  /// Parses HTML quote with <span> tag and returns AttributedString with bold
  /// accent formatting
  static func parseQuoteHTML(_ html: String?,
                             accentColor: Color) -> AttributedString?
  {
    guard let html else { return nil }

    var attributed = AttributedString()

    // Simple HTML parser for <span> tags
    var remaining = html
    while !remaining.isEmpty {
      if let spanStart = remaining.range(of: "<span>") {
        // Add text before span
        let before = String(remaining[..<spanStart.lowerBound])
        attributed.append(AttributedString(before))

        // Move past the opening tag
        remaining = String(remaining[spanStart.upperBound...])

        // Find closing tag
        if let spanEnd = remaining.range(of: "</span>") {
          let spanContent = String(remaining[..<spanEnd.lowerBound])

          // Add span content with bold and accent color
          var spanAttributed = AttributedString(spanContent)
          spanAttributed.font = .system(.body, design: .default, weight: .bold)
          spanAttributed.foregroundColor = accentColor
          attributed.append(spanAttributed)

          // Move past the closing tag
          remaining = String(remaining[spanEnd.upperBound...])
        } else {
          // Malformed HTML, just add the rest
          attributed.append(AttributedString(remaining))
          remaining = ""
        }
      } else {
        // No more spans, add remaining text
        attributed.append(AttributedString(remaining))
        remaining = ""
      }
    }

    return attributed
  }
}

// MARK: - SearchQueryFilter

/// Helper for filtering search query input
public enum SearchQueryFilter {
  public static func filter(_ input: String) -> String {
    let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)
    let lowercased = input.lowercased()

    // Replace 1+ consecutive invalid characters with single space
    var result = ""
    var lastWasInvalid = false

    for char in lowercased {
      if char.unicodeScalars
        .allSatisfy({ EbtQuery.allowedCharacters.contains($0) })
      {
        result.append(char)
        lastWasInvalid = false
      } else {
        let charDisplay = String(char).debugDescription
        if !lastWasInvalid {
          cc.bad1(#line, #function, "rejected:", charDisplay)
          result.append("?")
          lastWasInvalid = true
        } else {
          cc.bad1(#line, #function, "ignored:", charDisplay)
        }
      }
    }

    // Trim and collapse multiple spaces to single space
    return result.replacingOccurrences(
      of: "  +",
      with: " ",
      options: .regularExpression,
    )
  }
}

// MARK: - SearchCardView

/// Search card view with custom toolbar TextField for searchQuery editing
/// Phase 1: Allow user to enter search query and confirm with return key
public struct SearchCardView<Card: ICard, Manager: ICardManager>: View
  where Manager.ManagedCard == Card
{
  @Binding var card: Card
  let cardManager: Manager
  let isPhone = UIDevice.current.userInterfaceIdiom == .phone
  @EnvironmentObject var themeProvider: ThemeProvider
  @State private var tipitakaRefs: [TipitakaRef] = []
  @State private var tipitakaLoading: Bool = false
  @State private var searchQuery: String = ""
  @State private var suggestions: [PhraseAsset] = []
  @State private var debounceTimer: Timer?
  @FocusState private var focused: AppFocus?
  @FocusState private var searchFieldIsFocused: Bool
  @State private var searchTitle: String = "card.title.search".localized
  @State private var selectedResultId: String?
  @Environment(\.sizeCategory) var sizeCategory
  @Environment(\.accessibilityReduceMotion) var reduceMotion
  let appIcon: Image
  let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)

  private var shouldStackVertically: Bool {
    sizeCategory.isAccessibilityCategory
  }

  public init(
    card: Binding<Card>,
    cardManager: Manager,
    appIcon: Image? = nil,
  ) {
    _card = card
    self.cardManager = cardManager
    self.appIcon = appIcon ?? Image(systemName: "app.circle")
  }

  // MARK: - Private Methods

  private func onChangeSearchQuery(newValue: String) {
    cc.ok2(#line, #function, "searchQuery:", newValue)

    debounceTimer?.invalidate()
    debounceTimer = Timer.scheduledTimer(
      withTimeInterval: 0.5,
      repeats: false,
    ) { _ in
      Task { @MainActor in
        updateSuggestions(newValue)
      }
    }
    cc.ok1(#line, "searchQuery:", newValue)
  }

  private func applySearchModifiers(_ view: some View) -> some View {
    let step1 = view
      .toolbar {
        ToolbarItem(placement: {
          #if os(iOS)
            return isPhone ? .navigationBarTrailing : .principal
          #else
            return .automatic
          #endif
        }()) {
          Text(searchTitle)
            .font(.headline)
            .foregroundColor(themeProvider.theme.textColor)
            .lineLimit(1)
        }
      }

    let step2: AnyView = {
      #if os(iOS)
        return AnyView(step1
          .toolbarBackground(
            themeProvider.theme.backgroundColor,
            for: .navigationBar,
          )
          .toolbarBackground(.visible, for: .navigationBar))
      #else
        return AnyView(step1)
      #endif
    }()

    return step2
      .searchable(
        text: $searchQuery,
        prompt: "Search",
      )
      .searchSuggestions {
        ForEach(suggestions, id: \.lemma) { suggestion in
          Button(action: {
            searchQuery = suggestion.lastUsedPhrase
            cc.ok2(#line, "searchSuggestions:", suggestion.lastUsedPhrase)
          }) {
            HStack {
              Text(suggestion.lastUsedPhrase)
              Spacer()
              Text("★ \(String(format: "%.2f", suggestion.utility))")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .searchCompletion(suggestion.lastUsedPhrase)
        }
      }
      //.searchFocused($searchFieldIsFocused)
      .onChange(of: focused) { _, newValue in
        cc.ok1(#line, "onChange focused:", newValue)
      }
      .onChange(of: searchQuery) { _, newValue in
        onChangeSearchQuery(newValue: newValue)
      }
      .onSubmit(of: .search) {
        cc.ok2(#line, "onSubmit:", searchQuery)
        searchTitle = searchQuery + "..."
        SearchCardView.searchSubmitHandler(
          cardManager: cardManager,
          selectedCardId: card.id,
          searchQueryBinding: $searchQuery,
          searchTitleBinding: $searchTitle,
        )
        cc.ok1(#line, "onSubmit:", searchQuery)
      }
      .onDisappear {
        debounceTimer?.invalidate()
        debounceTimer = nil
      }
      .onChange(of: card.searchQuery) { _, newValue in
        searchQuery = newValue

        let filtered = SearchQueryFilter.filter(newValue)
        if filtered != newValue {
          card.searchQuery = filtered
        }
        cc.ok1(#line, "onChange card.searchQuery:", filtered)
      }
      .onAppear {
        searchQuery = card.searchQuery
        searchFieldIsFocused = true

        if let result = card.searchResult, !result.items.isEmpty {
          searchTitle = card.searchQuery + " (\(result.items.count))"
        } else {
          let langCode = Settings.shared.docLang.code.uppercased()
          let authorAbbr = Settings.shared.docAuthor
          let authorInfo = DatabaseManifest.shared.info(
            language: Settings.shared.docLang.code,
            author: authorAbbr,
          )
          let authorName = authorInfo?.authorName ?? authorAbbr
          searchTitle = "\(langCode) \(authorName)"
        }

        cc.ok1(#line, "onAppear",
               "searchFieldIsFocused:", searchFieldIsFocused,
               "searchTitle:", searchTitle)
      }
  }

  private func populateSuttaInfoInBackground(
    searchResult: SeekerResult,
    cardManager: Manager,
    cardId: AnyHashable,
  ) {
    cc.ok2(
      #line,
      "Starting background sutta info population for \(searchResult.items.count) items",
    )

    Task {
      var updatedResult = searchResult
      let success = await updatedResult.populateItems()

      if success {
        if let card = cardManager.cardFromId(cardId) {
          var updatedCard = card
          updatedCard.searchResult = updatedResult
          cardManager.saveCard(updatedCard)
          cc.ok1(#line, "Saved card with populated segment info")
        } else {
          cc.bad1(#line, "Card not found for id:", cardId)
        }
      } else {
        cc.bad1(#line, "Failed to populate sutta info")
      }
    }
  }

  private func loadTipitaka() {
    let lang = Settings.shared.docLang.code
    let author = Settings.shared.docAuthor
    cc.ok2(#line, #function, lang, author)

    tipitakaLoading = true

    Task {
      cc.ok2(#line, #function, "loading...", lang, author)
      let root = await Tipitaka.authorTipitaka(lang: lang, author: author)
      tipitakaRefs = root.children ?? []
      tipitakaLoading = false
      cc.ok1(#line, #function, "loaded \(tipitakaRefs.count) root refs")
    }
  }

  private func updateSuggestions(_ query: String) {
    guard !query.isEmpty else {
      suggestions = []
      return
    }

    Task { @MainActor in
      let newSuggestions = AutoComplete.shared.suggest(
        prefix: query,
        author: Settings.shared.docAuthor,
        lang: Settings.shared.docLang.code,
      )

      cc.ok1(#line, #function, "query:", query,
             "found:", newSuggestions.count)
      suggestions = newSuggestions
    }
  }

  private var resultsView: some View {
    // Check if no search results (either nil or empty items)
    let hasNoResults = card.searchResult == nil ||
      (card.searchResult?.items.isEmpty ?? true)

    if hasNoResults {
      return AnyView(
        GeometryReader { geometry in
          VStack {
            Spacer()
            HStack {
              Spacer()
              // Show TipitakaView if loaded, otherwise show loading/icon
              if !tipitakaRefs.isEmpty {
                TipitakaView(
                  tipitakaRefs: tipitakaRefs,
                  cardManager: cardManager,
                )
                .frame(
                  maxWidth: min(500, geometry.size.width),
                  maxHeight: .infinity,
                )
              } else if tipitakaLoading {
                ScvProgressView(appIcon: appIcon, label: "Loading Tipiṭaka...")
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
              } else {
                // Unexpected wait
                ScvProgressView(appIcon: appIcon, label: "Nothingness...")
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
              }
              Spacer()
            }
            Spacer()
          }
          .onAppear {
            loadTipitaka()
          }
        },
      )
    }

    // Check for error
    guard let searchResult = card.searchResult else {
      return AnyView(EmptyView())
    }

    if let error = searchResult.error {
      return AnyView(
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.circle")
            .font(.title2)
            .foregroundColor(themeProvider.theme.errorTextColor)
          Text("card.search.error".localized)
            .font(.headline)
            .foregroundColor(themeProvider.theme.textColor)
          Text(error.message)
            .font(.body)
            .foregroundColor(themeProvider.theme.errorTextColor)
            .lineLimit(shouldStackVertically ? 4 : 3)
          if !error.detail.isEmpty {
            Text(error.detail)
              .font(.caption)
              .foregroundColor(themeProvider.theme.secondaryTextColor)
              .lineLimit(shouldStackVertically ? 3 : 2)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(),
      )
    }

    // Display results
    return AnyView(
      VStack(alignment: .leading, spacing: 12) {
        // Results list
        List(Array(searchResult.items.enumerated()),
             id: \.element.suttaRef)
        { index, item in
          Button(action: {
            let resultId = item.suttaRef.toString()
            if selectedResultId == resultId {
              // Already focused: navigate to sutta card
              Task {
                let suttaCard = await cardManager.suttaCardForRef(
                  item.suttaRef,
                  searchQuery: card.searchQuery,
                )
                cardManager.selectCard(suttaCard)
                cc.ok1(#line, "Selected sutta card for:", selectedResultId)
              }
            } else {
              // Not focused: set focus
              // focused = .resultRow(id:resultId)
              cc.ok1(
                #line,
                #function,
                "focused",
                focused,
                "resultId:",
                resultId,
              )
              selectedResultId = resultId
              cc.ok1(#line, "focus:", selectedResultId)
            }
          }) { // Button content
            HStack {
              Text("\(index + 1).")
                .font(.caption)
                .foregroundColor(themeProvider.theme.textColor)
                .fontWeight(.semibold)
                .frame(minWidth: 14, alignment: .leading)
              VStack(alignment: .leading, spacing: 4) {
                if shouldStackVertically {
                  // Vertical stack for accessibility sizes
                  VStack(alignment: .leading, spacing: 2) {
                    Text(item.suttaRef.author ?? "unknown")
                      .font(.caption)
                      .foregroundColor(themeProvider.theme.textColor)
                      .fontWeight(.semibold)
                    HStack {
                      Text(
                        "★ \(String(format: "%.2f", item.score))",
                      )
                      .font(.caption)
                      .foregroundColor(themeProvider.theme.textColor)
                      .fontWeight(.semibold)
                      Spacer()
                      Text(
                        item.segmentCount.map(String.init) ?? "…",
                      )
                      .font(.caption)
                      .foregroundColor(themeProvider.theme.textColor)
                      .fontWeight(.semibold)
                    }
                  }
                } else {
                  // Horizontal stack for normal sizes
                  HStack {
                    Text(item.suttaRef.author ?? "unknown")
                      .font(.caption)
                      .foregroundColor(themeProvider.theme.textColor)
                      .fontWeight(.semibold)
                    Spacer()
                    Text(
                      "★ \(String(format: "%.2f", item.score))",
                    )
                    .font(.caption)
                    .foregroundColor(themeProvider.theme.textColor)
                    .fontWeight(.semibold)
                    Text(
                      item.segmentCount.map(String.init) ?? "…",
                    )
                    .font(.caption)
                    .foregroundColor(themeProvider.theme.textColor)
                    .fontWeight(.semibold)
                    .frame(minWidth: 30, alignment: .trailing)
                  }
                }
                Text(item.suttaRef.suttaUid)
                  .font(.body)
                  .fontWeight(.semibold)
                  .foregroundColor(themeProvider.theme.textColor)

                // Display quote if available
                if let quote = item.quote,
                   let attributed = QuoteHTMLParser.parseQuoteHTML(
                     quote,
                     accentColor: themeProvider.theme.accentColor,
                   )
                {
                  Text(attributed)
                    .font(.caption)
                    .foregroundColor(themeProvider.theme.secondaryTextColor)
                    .lineLimit(shouldStackVertically ? 5 : 3)
                }
              } // VStack
              .padding(.vertical, 4)
            } // HStack
          } // Button content
          .buttonStyle(.plain)
          .accessibilityLabel(String(
            format: "a11y.result".localized,
            index + 1,
          ))
          .focused($focused, equals: .resultRow(id: item.suttaRef.toString()))
          .keyboardShortcut(.defaultAction)
          .listRowBackground(selectedResultId == item.suttaRef.toString()
            ? themeProvider.theme.backgroundColor
            : themeProvider.theme.cardBackground)
          .listRowSeparator(selectedResultId == item.suttaRef
            .toString() ? .hidden :
            .automatic)
        } // List
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 700)
        #if os(iOS)
          .listStyle(.insetGrouped)
        #else
          .listStyle(.automatic)
        #endif
      }.focusable(),
    )
  } // resultsView

  // MARK: - Static Methods

  static func searchSubmitHandler(
    cardManager: Manager,
    selectedCardId: AnyHashable,
    searchQueryBinding: Binding<String>,
    searchTitleBinding: Binding<String>,
  ) {
    let cc = ColorConsole(#file, #function, dbg.SearchCardView.other)
    // Fetch fresh card from manager to ensure we have current state
    guard var card = cardManager.cardFromId(selectedCardId) else {
      cc.bad1(#line, "Card not found for id:", selectedCardId)
      return
    }

    // SYNC: Update card with current binding value before saving
    let searchQuery = searchQueryBinding.wrappedValue
    card.searchQuery = searchQuery
    cardManager.saveCard(card)

    cc.ok1(#line, "Search submitted:", searchQuery)

    // Execute search asynchronously
    Task {
      let ebtQuery = EbtQuery(query: searchQuery)
      let searchResult = await ebtQuery.search()

      // Update card with search result
      card.searchResult = searchResult
      cardManager.saveCard(card)

      // Update search title with result count
      DispatchQueue.main.async {
        searchTitleBinding.wrappedValue = searchQueryBinding.wrappedValue + " (\(searchResult.items.count))"
      }

      if let error = searchResult.error {
        cc.bad1(#line, "Search failed:", error.message, "detail:", error.detail)
      } else {
        cc.ok1(
          #line,
          "Search completed with \(searchResult.items.count) results",
        )

        // Track phrase in AutoComplete only for lemma searches with results
        if searchResult.items.count > 0,
           searchResult.metadata.method == .lemma
        {
          AutoComplete.shared.track(
            phrase: searchQuery,
            documentCount: searchResult.items.count,
            author: searchResult.metadata.docAuthor,
            lang: searchResult.metadata.docLang,
          )
        }

        // Trigger background sutta info and quote population
        // Note: We need to spawn this on the main thread context
        // Create a temporary view instance to call the instance method
        DispatchQueue.main.async {
          let view = SearchCardView<Manager.ManagedCard, Manager>(
            card: .constant(card),
            cardManager: cardManager,
          )
          view.populateSuttaInfoInBackground(
            searchResult: searchResult,
            cardManager: cardManager,
            cardId: selectedCardId,
          )
        }
      }
    }

    // FIXME: SwiftUI bug with searchable() - text field clears after onSubmit
    // See: https://developer.apple.com/forums/thread/734087
    // Workaround: Clear and restore binding to force UI sync
    // NOTE: This is async and runs AFTER logging so it doesn't interfere with
    // card state
    searchQueryBinding.wrappedValue = ""
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      searchQueryBinding.wrappedValue = searchQuery
    }
  }

  public var body: some View {
    if isPhone {
      ZStack(alignment: .bottom) {
        applySearchModifiers(
          resultsView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(0),
        )
        VStack(spacing: 0) {
          Spacer()
          Rectangle()
            .fill(themeProvider.theme.cardBackground)
            .frame(height: 84)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      }
      .ignoresSafeArea()
    } else {
      applySearchModifiers(
        resultsView
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(0),
      )
    }
  }
}

// MARK: - Preview

#Preview("SearchCardView") {
  @Previewable @State var selectedCardId: AnyHashable? = nil
  @Previewable @State var mockCard1 = PreviewCard(
    cardType: .search,
    typeId: 1,
    searchQuery: "mindfulness",
  )

  let card1 = PreviewCard(
    cardType: .search,
    typeId: 1,
    searchQuery: "mindfulness",
  )
  let card2 = PreviewCard(
    cardType: .search,
    typeId: 2,
    searchQuery: "suffering",
  )
  let manager = PreviewCardManager(
    cards: [card1, card2],
    selectedCardId: card1.id,
  )

  NavigationSplitView {
    CardSidebarView(
      cardManager: manager,
      selectedCardId: $selectedCardId,
    )
    .onAppear {
      let ref1 = SuttaRef.create("mn119/en/sujato")
      let ref2 = SuttaRef.create("mn11/en/sujato")
      if ref1 != nil, ref2 != nil {
        mockCard1.searchResult = SeekerResult(
          metadata: SearchMetadata(
            timestamp: Date(),
            query: "mindfulness",
            method: .lemma,
            elapsedTime: 0.045,
            docLang: "en",
            docAuthor: "sujato",
          ),
          items: [
            .init(
              suttaRef: ref1!,
              score: 0.95,
              segmentCount: 42,
              quote: "Mindfulness is the path to the Deathless...",
            ),
            .init(
              suttaRef: ref2!,
              score: 0.87,
              segmentCount: 58,
              quote: "Through mindfulness, through heedfulness...",
            ),
          ],
        ) // SeekerResult
      } // if
    } // onAppear
  } detail: {
    ZStack {
      SearchCardView(card: $mockCard1, cardManager: manager)
    } // ZStack
    .background(ScvBackgroundsView(.palm_leaf))
  }
  .environmentObject(ThemeProvider())
}
