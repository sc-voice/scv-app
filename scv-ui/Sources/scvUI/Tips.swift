import scvCore
import SwiftUI

// MARK: - TipsAction

/// Identifies which tip/guidance animation to show
enum TipsAction {
  case addCard
  // Future tips can be added here
}

// MARK: - Tips

/// Manages new user guidance effects and state
enum Tips {
  /// Returns whether tips/guidance should be shown for a specific action
  /// - Parameter action: The tip action to check
  /// - Parameter cardManager: CardManager instance (uses CardManager.shared if
  /// nil)
  @MainActor
  static func active(
    _ action: TipsAction,
    cardManager: (any ICardManager)? = nil,
  ) -> Bool {
    let manager = cardManager ?? CardManager.shared
    let hasNoCards = manager.allCards.count == 1
      && manager.allCards.first?.cardType == .about

    switch action {
    case .addCard:
      return hasNoCards
    }
  }
}

// MARK: - TipsClickMeModifier

/// Animates a view with a wiggle and color transition when Tips.active() is
/// true
/// - Motion: Single up/down wiggle (8pt offset) over 1 second
/// - Color: 3-second transition to theme accent color
struct TipsClickMeModifier: ViewModifier {
  let action: TipsAction
  let cardManager: (any ICardManager)?
  @Environment(\.accessibilityReduceMotion) var reduceMotion
  @EnvironmentObject var themeProvider: ThemeProvider

  @State private var xOffsetValue: Double = -32
  @State private var foregroundColor: Color?

  func body(content: Content) -> some View {
    let isActive = Tips.active(action, cardManager: cardManager)

    if isActive, !reduceMotion {
      content
        .offset(x: xOffsetValue)
        .foregroundStyle(foregroundColor ?? themeProvider.theme.textColor)
        .onAppear {
          startAnimations()
        }
    } else {
      content
    }
  }

  private func startAnimations() {
    // 1-second color transition from textColor to accent color
    withAnimation(.easeInOut(duration: 1.0)) {
      foregroundColor = themeProvider.theme.accentColor
    }

    // Slide: -32 → +8 over 1s, then +8 → 0 over 3s (starts after color animation)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      // Move from left -32 to right +8 over 1s
      withAnimation(.easeInOut(duration: 1.0)) {
        xOffsetValue = 8
      }

      // Move from +8 back to center 0 over 3s
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        withAnimation(.easeInOut(duration: 3.0)) {
          xOffsetValue = 0
        }
      }
    }
  }
}

// MARK: - Extension

extension View {
  /// Applies Tips.clickMe animation when Tips.active() is true for the given
  /// action
  /// - Parameter action: The tip action to check
  /// - Parameter cardManager: CardManager instance (uses CardManager.shared if
  /// nil)
  /// - Wiggle: Up/down motion over 1 second for emphasis
  /// - Color: 3-second transition to theme accent color
  func clickMe(_ action: TipsAction,
               cardManager: (any ICardManager)? = nil) -> some View
  {
    modifier(TipsClickMeModifier(action: action, cardManager: cardManager))
  }
}
