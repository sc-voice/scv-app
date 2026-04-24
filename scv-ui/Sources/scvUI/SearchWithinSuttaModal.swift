//
//  SearchWithinSuttaModal.swift
//  scv-ui
//
//  Created by Claude on 2026-04-24.
//

import scvCore
import SwiftUI

// MARK: - SearchWithinSuttaModal

struct SearchWithinSuttaModal: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var themeProvider: ThemeProvider
  @Binding var searchQuery: String
  @State private var results: [Segment] = []
  @State private var isSearching = false
  let suttaRef: SuttaRef
  let currentScid: String?
  let onSelectSegment: (Segment) -> Void
  let cc = ColorConsole(#file, #function, dbg.SuttaCardView.other)

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        SearchField(
          query: $searchQuery,
          isSearching: $isSearching,
          onSearch: performSearch
        )

        if results.isEmpty && !searchQuery.isEmpty && !isSearching {
          VStack(alignment: .center, spacing: 12) {
            Image(systemName: "magnifyingglass")
              .font(.title)
              .foregroundColor(themeProvider.theme.secondaryTextColor)
            Text("search.no_results".localized)
              .foregroundColor(themeProvider.theme.secondaryTextColor)
          }
          .frame(maxHeight: .infinity)
          .padding()
        } else {
          SearchResultsList(
            results: results,
            currentScid: currentScid,
            onSelectSegment: selectSegment
          )
        }
      }
      .background(themeProvider.theme.backgroundColor)
      .onAppear { performSearch() }
      .navigationTitle("search.within_sutta".localized)
      .tint(themeProvider.theme.toolbarForeground)
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(themeProvider.theme.toolbarBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
      #endif
      .toolbar {
        #if os(iOS)
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { dismiss() }) {
              Image(systemName: "xmark")
                .foregroundColor(themeProvider.theme.toolbarForeground)
            }
          }
        #else
          ToolbarItem(placement: .automatic) {
            Button(action: { dismiss() }) {
              Image(systemName: "xmark")
                .foregroundColor(themeProvider.theme.toolbarForeground)
            }
          }
        #endif
      }
    }
  }

  private func performSearch() {
    guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
      results = []
      return
    }

    isSearching = true
    Task {
      do {
        let seeker = try await EbtData.getSeeker(suttaRef: suttaRef)
        let segments = await seeker.searchWithinSutta(suttaRef: suttaRef, query: searchQuery)
        await MainActor.run {
          results = segments
          isSearching = false
        }
      } catch {
        cc.bad1(#line, #function, "Search failed: \(error)")
        await MainActor.run {
          results = []
          isSearching = false
        }
      }
    }
  }

  private func selectSegment(_ segment: Segment) {
    onSelectSegment(segment)
    dismiss()
  }
}

// MARK: - SearchField

struct SearchField: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  @Binding var query: String
  @Binding var isSearching: Bool
  let onSearch: () -> Void

  var body: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundColor(themeProvider.theme.toolbarForeground)

      TextField("search.placeholder".localized, text: $query)
        .textFieldStyle(.roundedBorder)
        .onChange(of: query) { _, _ in
          onSearch()
        }

      if !query.isEmpty {
        Button(action: { query = "" }) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(themeProvider.theme.toolbarForeground)
        }
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 8)
    .background(themeProvider.theme.toolbarBackground)
  }
}

// MARK: - SearchResultsList

struct SearchResultsList: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  let results: [Segment]
  let currentScid: String?
  let onSelectSegment: (Segment) -> Void

  private var nearestScid: String? {
    (results.first(where: { SuttaCentralId.compareLow($0.scid, currentScid ?? "") >= 0 })
      ?? results.first)?.scid
  }

  var body: some View {
    ScrollViewReader { proxy in
      List {
        ForEach(results, id: \.scid) { segment in
          SearchResultRow(segment: segment, isNearest: segment.scid == nearestScid)
            .onTapGesture { onSelectSegment(segment) }
            .id(segment.scid)
            .listRowBackground(
              segment.scid == nearestScid
                ? themeProvider.theme.accentColor.opacity(0.15)
                : themeProvider.theme.backgroundColor
            )
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(themeProvider.theme.backgroundColor)
      .onChange(of: results) { _, _ in
        if let scid = nearestScid { proxy.scrollTo(scid, anchor: .top) }
      }
    }
  }
}

// MARK: - SearchResultRow

struct SearchResultRow: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  let segment: Segment
  let isNearest: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(segment.scid)
        .font(.caption)
        .foregroundColor(isNearest ? themeProvider.theme.accentColor : themeProvider.theme.secondaryTextColor)

      if let doc = segment.doc {
        Text(truncateText(doc, maxLength: 100))
          .font(.body)
          .lineLimit(2)
          .foregroundColor(themeProvider.theme.textColor)
      }
    }
    .padding(.vertical, 8)
  }

  private func truncateText(_ text: String, maxLength: Int) -> String {
    if text.count > maxLength {
      let endIndex = text.index(text.startIndex, offsetBy: maxLength)
      return String(text[..<endIndex]) + "…"
    }
    return text
  }
}

