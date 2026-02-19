import scvCore
import SwiftUI

// MARK: - TipView

/// A modal tip sheet with a title, body text, X close button, and OK button.
/// Caller controls visibility via `isPresented` binding.
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showTip) {
///   TipView(title: "tip.title".localized,
///           text: "tip.body".localized,
///           isPresented: $showTip)
///     .presentationDetents([.medium])
/// }
/// ```
public struct TipView: View {
  @EnvironmentObject var themeProvider: ThemeProvider
  let title: String
  let text: String
  @Binding var isPresented: Bool
  let onConfirm: (() -> Void)?

  public init(
    title: String,
    text: String,
    isPresented: Binding<Bool>,
    onConfirm: (() -> Void)? = nil,
  ) {
    self.title = title
    self.text = text
    _isPresented = isPresented
    self.onConfirm = onConfirm
  }

  public var body: some View {
    let bg = themeProvider.theme.tipBackground
    let fg = themeProvider.theme.tipForeground

    ZStack {
      bg

      VStack(spacing: 0) {
        // MARK: Header

        HStack {
          Text(title)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(fg)
          Spacer()
          Button(action: { isPresented = false }) {
            Image(systemName: "xmark")
              .font(.body)
              .foregroundColor(fg)
              .frame(minWidth: 44, minHeight: 44)
          }
        }
        .padding()
        .background(bg)
        .overlay(alignment: .bottom) {
          Rectangle()
            .fill(fg.opacity(0.3))
            .frame(height: 0.5)
        }

        // MARK: Body

        ScrollView {
          Text(text)
            .font(.body)
            .foregroundColor(fg)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(bg)

        // MARK: Footer

        Button(action: { isPresented = false; onConfirm?() }) {
          Text("OK")
            .font(.body)
            .foregroundColor(fg)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .background(bg)
        .overlay(alignment: .top) {
          Rectangle()
            .fill(fg.opacity(0.3))
            .frame(height: 0.5)
        }
      }
    }
  }
}

// MARK: - Preview

#Preview {
  TipView(
    title: "Add a Card",
    text: "Tap the + button to add a search card. You can search for suttas by keyword, sutta ID, or topic.",
    isPresented: .constant(true),
  )
  .environmentObject(ThemeProvider())
  .presentationDetents([.medium])
}
