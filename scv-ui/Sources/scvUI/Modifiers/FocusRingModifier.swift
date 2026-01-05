import SwiftUI

struct FocusRing<T: Hashable>: ViewModifier {
  let id: T
  var isFocused: Bool
  var color: Color

  func body(content: Content) -> some View {
    content
      .background(isFocused ? color.opacity(0.1) : Color.clear)
      .border(isFocused ? color : Color.clear, width: 3)
  }
}

extension View {
  func focusRing(_ id: some Hashable, isFocused: Bool,
                 color: Color = .blue) -> some View
  {
    modifier(FocusRing(id: id, isFocused: isFocused, color: color))
  }
}
