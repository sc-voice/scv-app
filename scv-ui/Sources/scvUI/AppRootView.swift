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
  #if os(iOS)
    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
  #else
    let isPhone = false
  #endif
  var cardManager: Manager
  @EnvironmentObject var themeProvider: ThemeProvider
  @State private var showSettings = false
  @State private var settingsController = SettingsModalController(from: Settings
    .shared)
  @State private var isReady = false
  let appIcon: Image?
  let cc = ColorConsole(#file, #function, dbg.AppRootView.other)

  public init(
    cardManager: Manager,
    appIcon: Image? = nil,
    isReady: Bool = false,
  ) {
    self.cardManager = cardManager
    self.appIcon = appIcon
    self.isReady = isReady
  }

  public var body: some View {
    ZStack {
      VStack(spacing: 0) {
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
            } else {
              VStack(spacing: 16) {
                Image(systemName: "square.3.layers.3d")
                  .font(.title)
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
          .background(ScvBackgroundsView(.palm_leaf))
        } // detail:
        #if os(iOS)
        .navigationSplitViewStyle(.balanced)
        #endif
        .onAppear {
          cc.ok2(#line, #function, cardManager.allCards.count, "cards")
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
              cc.ok2(#line, #function, "UIKeyboardWillShow")
            }

            NotificationCenter.default.addObserver(
              forName: UIResponder.keyboardDidShowNotification,
              object: nil,
              queue: .main,
            ) { _ in
              cc.ok2( #line, #function, "UIKeyboardDidShow")
            }
          #endif

          // Probe main thread responsiveness every 50ms until it responds
          DispatchQueue.global(qos: .background).async { [cc] in
            var mainActorBusy = true
            var checkCount = 0
            while mainActorBusy, checkCount < 300 {
              let sem = DispatchSemaphore(value: 0)
              DispatchQueue.main.async { sem.signal() } // simple probe
              // Wait up to 100ms for main thread to execute
              if sem.wait(timeout: .now() + 0.1) == .success {
                cc.ok1(#line, #function, "MainThread now responsive")
                mainActorBusy = false
                // Dismiss splash screen once MainActor is responsive
                DispatchQueue.main.async {
                  isReady = true
                }
              }
              checkCount += 1
            }
          }

          // View hierarchy is now stabilized; SearchCardView will manage search
          // focus
        }
        .task {
          let lang = Settings.shared.docLang
          let author = Settings.shared.docAuthor
          cc.ok2(#line, #function, lang, author, "EbtData.forLangAuthor()...")
          guard let ebtData = await EbtData.forLangAuthor(lang: lang.rawValue, author: author) else { return }
          let git_hash_timestamp = await ebtData.getMetaprop(lang: lang.rawValue, author: author, key: "git_hash_timestamp")
          cc.ok1(#line, #function, "content:", git_hash_timestamp ?? "nil")
        }
        .onChange(of: cardManager.selectedCardId) {
          let idString = cardManager.selectedCardId
            .map { String(describing: $0) } ?? "nil"
          cc.ok2(#line, #function, "selectedCardId:", idString)
        }
        .sheet(isPresented: $showSettings) {
          SettingsView(controller: settingsController)
            .environmentObject(themeProvider)
        }
        .modifier(SheetBackgroundDimmingModifier(isPresented: $showSettings))
      } // VStack

      if !isReady {
        SplashScreenView(appIcon: appIcon)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(ScvBackgroundsView(.village))
      }
    } // ZStack
    .background(ScvBackgroundsView(.village))
  } // body

  @ViewBuilder
  private func detailView(for cardId: AnyHashable,
                          cardBinding: Binding<Manager.ManagedCard>?)
    -> some View
  {
    let _ = cc.ok2( #line, #function,
      "selectedCardId:",
      cardManager.selectedCardId as Any,
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
        )
        .environmentObject(themeProvider)
        .onAppear {
          cc.ok1(#line, "SearchCardView appeared on screen")
        }

      case .sutta:
        SuttaCardView(
          card: cardBinding,
          cardManager: cardManager,
        )
        .environmentObject(themeProvider)

      case .about:
        AboutCardView(card: card, cardManager: cardManager)
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
  let card1 = PreviewCard(
    cardType: .search,
    typeId: 1,
    searchQuery: "mindfulness",
  )

  let manager = PreviewCardManager(
    cards: [card1],
    selectedCardId: card1.id,
  )

  let themeProvider = ThemeProvider()

  AppRootView(cardManager: manager, isReady: true)
    .environmentObject(themeProvider)
}
