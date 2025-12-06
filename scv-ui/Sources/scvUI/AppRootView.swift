//
//  AppRootView.swift
//  scv-ui
//
//  Created by Claude on 2025-11-19.
//

import scvCore
import SwiftUI
#if os(iOS)
  import UIKit
#endif

// MARK: - AppRootView

/// Root view for SCV app with card management and NavigationSplitView layout
public struct AppRootView<Manager: ICardManager>: View {
  var cardManager: Manager
  @EnvironmentObject var themeProvider: ThemeProvider
  @State private var isSearchFocused: Bool = false
  @FocusState private var searchFieldIsFocused: Bool
  @State private var showSettings = false
  @State private var settingsController = SettingsModalController(from: Settings
    .shared)
  @State private var rootSearchQuery: String = ""
  @State private var isReady = false
  let appIcon: Image?
  let cc = ColorConsole(#file, #function, dbg.AppRootView.other)

  public init(cardManager: Manager, appIcon: Image? = nil) {
    self.cardManager = cardManager
    self.appIcon = appIcon
  }

  public var body: some View {
    ZStack {
      VStack(spacing: 0) {
        Text("v\(appVersion)")
          .foregroundStyle(themeProvider.theme.debugForeground)
        NavigationSplitView {
          // Sidebar with card list
          CardSidebarView(
            cardManager: cardManager,
            selectedCardId: Binding(
              get: { cardManager.selectedCardId },
              set: { newValue in
                cc.ok2(
                  #line,
                  "selectCardId:",
                  newValue.map { String(describing: $0) } ?? "nil",
                )
                cardManager.selectCardId(newValue)
              },
            ),
            onSettingsTap: {
              cc.ok1(#line, "Settings gear button pressed from sidebar")
              showSettings = true
            },
          )
        } detail: {
          ZStack {
            // Detail view based on selected card
            if let selectedCardId = cardManager.selectedCardId,
               let cardBinding = cardManager.bindCard(id: selectedCardId)
            {
              detailView(for: selectedCardId, cardBinding: cardBinding)
                .id(selectedCardId) // Force complete rebuild when
                // selectedCardId
                // changes
                .onAppear {
                  cc.ok1(#line, "Detail view layout complete")
                }
                .searchable(
                  text: $rootSearchQuery,
                  isPresented: $isSearchFocused,
                  placement: {
                    #if os(iOS)
                      return .navigationBarDrawer(displayMode: .automatic)
                    #else
                      return .toolbar
                    #endif
                  }(),
                  prompt: "Search",
                )
                .focused($searchFieldIsFocused)
                .onChange(of: isSearchFocused) { _, newValue in
                  cc.ok1(#line, "isSearchFocused changed to:", newValue)
                }
                .onChange(of: searchFieldIsFocused) { _, newValue in
                  cc.ok1(
                    #line,
                    "searchFieldIsFocused (TextField actual focus) changed to:",
                    newValue,
                  )
                }
                .onChange(of: rootSearchQuery) { _, newValue in
                  cc.ok1(
                    #line,
                    "rootSearchQuery changed in keyboard to:",
                    newValue,
                  )
                  // Note: Card updates are handled by
                  // SearchCardView.searchSubmitHandler
                  // on search submission, not by onChange here
                }
                .onAppear {
                  cc.ok1(
                    #line,
                    "searchable modifier appeared, isSearchFocused:",
                    isSearchFocused,
                  )
                }
                .onSubmit(of: .search) {
                  cc.ok1(#line, "Search submitted in keyboard")
                  SearchCardView.searchSubmitHandler(
                    cardManager: cardManager,
                    selectedCardId: selectedCardId,
                    searchQueryBinding: $rootSearchQuery,
                  )
                  isSearchFocused = false
                }
            } else {
              VStack(spacing: 16) {
                Image(systemName: "square.3.layers.3d")
                  .font(.system(size: 48))
                  .foregroundStyle(.secondary)
                Text("No card selected")
                  .font(.headline)
                Text("Select a card from the sidebar")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          } // ZStack
          .environmentObject(themeProvider)
          .background(themeProvider.theme.cardBackground)
        } // detail:
        .onAppear {
          cc.ok1(
            #line,
            "AppRootView initialized with",
            cardManager.allCards.count,
            "cards",
          )
          // Listen for keyboard notifications
          #if os(iOS)
            NotificationCenter.default.addObserver(
              forName: UIResponder.keyboardWillShowNotification,
              object: nil,
              queue: .main,
            ) { _ in
              // Known iOS 18 issue: ~7s delay between search focus request and
              // keyboard appearance
              // See: https://www.hackingwithswift.com/forums/swiftui/modifier-searchable-slow-on-ios-18-x/28323
              cc.ok2(#line, "UIKeyboardWillShow notification received")
            }

            NotificationCenter.default.addObserver(
              forName: UIResponder.keyboardDidShowNotification,
              object: nil,
              queue: .main,
            ) { _ in
              cc.ok1(
                #line,
                "UIKeyboardDidShow notification received - keyboard is interactive",
              )
            }
          #endif

          // Probe main thread responsiveness every 50ms until it responds
          DispatchQueue.global(qos: .background).async {
            var mainActorBusy = true
            var checkCount = 0
            while mainActorBusy, checkCount < 300 {
              let sem = DispatchSemaphore(value: 0)
              DispatchQueue.main.async { sem.signal() } // simple probe
              // Wait up to 100ms for main thread to execute
              if sem.wait(timeout: .now() + 0.1) == .success {
                cc.ok1(#line, "MainThread now responsive")
                mainActorBusy = false
                // Dismiss splash screen once MainActor is responsive
                DispatchQueue.main.async {
                  isReady = true
                }
              }
              checkCount += 1
            }
          }

          // Delay search focus to allow view hierarchy to stabilize
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cc.ok1(#line, "Enabling search focus after delay")
            isSearchFocused = true
          }
        }
        .onChange(of: cardManager.selectedCardId) {
          let idString = cardManager.selectedCardId
            .map { String(describing: $0) } ?? "nil"
          cc.ok2(#line, "selectedCardId:", idString)

          // Sync rootSearchQuery with new card's searchQuery
          if let cardId = cardManager.selectedCardId,
             let card = cardManager.cardFromId(cardId)
          {
            rootSearchQuery = card.searchQuery
          }
        }
        .sheet(isPresented: $showSettings) {
          SettingsView(controller: settingsController)
            .environmentObject(themeProvider)
        }
      } // VStack

      if !isReady {
        SplashScreenView(appIcon: appIcon)
          .background(themeProvider.theme.backgroundColor.opacity(0.5))
          .ignoresSafeArea()
          .zIndex(1)
      }
    } // ZStack
    .environmentObject(themeProvider)
    .background(themeProvider.theme.cardBackground)
    .ignoresSafeArea()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private func detailView(for cardId: Manager.ManagedCard.ID,
                          cardBinding: Binding<Manager.ManagedCard>?)
    -> some View
  {
    let _ = cc.ok2(
      #line,
      #function,
      "selectedCardId:",
      cardManager.selectedCardId,
      "cardId:",
      cardId,
    )
    if let cardBinding {
      // Use cardBinding.wrappedValue to safely access card (handles ghost
      // cards)
      let card = cardBinding.wrappedValue
      switch card.cardType {
      case .search:
        SearchCardView(
          card: cardBinding,
          cardManager: cardManager,
          appIcon: appIcon,
          isSearchFocused: isSearchFocused,
        )
        .environmentObject(themeProvider)
        .onAppear {
          cc.ok1(#line, "SearchCardView appeared on screen")
        }
        .toolbar {
          ToolbarItem(placement: {
            #if os(iOS)
              return .navigationBarTrailing
            #else
              return .automatic
            #endif
          }()) {
            Button(action: { isSearchFocused.toggle() }) {
              Image(systemName: "magnifyingglass")
                .font(.title2)
            }
            .buttonStyle(.plain)
            .help("Toggle search")
          }
        }

      case .sutta:
        SuttaCardView(
          card: cardBinding,
          cardManager: cardManager,
          isSearchFocused: isSearchFocused,
        )
        .environmentObject(themeProvider)
        .toolbar {
          ToolbarItem(placement: {
            #if os(iOS)
              return .navigationBarTrailing
            #else
              return .automatic
            #endif
          }()) {
            Button(action: { isSearchFocused.toggle() }) {
              Image(systemName: "magnifyingglass")
                .font(.title2)
            }
            .buttonStyle(.plain)
            .help("Toggle search")
          }
        }

      case .help:
        HelpCardView()
          .environmentObject(themeProvider)
      }
    } else {
      Text("Card not found")
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Preview

#Preview("AppRootView with 1 card", traits: .portrait) {
  let card1 = MockCard(
    cardType: .search,
    typeId: 1,
    searchQuery: "mindfulness",
  )

  let manager = MockCardManager(
    cards: [card1],
    selectedCardId: card1.id,
  )

  let themeProvider = ThemeProvider()

  AppRootView(cardManager: manager)
    .environmentObject(themeProvider)
  Text("AppRootView preview")
    .font(.caption)
    .foregroundStyle(themeProvider.theme.debugForeground)
    .ignoresSafeArea()
}
