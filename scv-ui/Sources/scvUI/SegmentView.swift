import scvCore
import SwiftUI
#if os(iOS)
  import UIKit
#endif

struct SegmentView: View {
  let cc = ColorConsole(#file, #function, dbg.SegmentView.other)
  let segment: Segment
  let mlDoc: MLDocument
  let layout: SegmentLayout
  @ObservedObject var player: SuttaPlayer

  @EnvironmentObject var themeProvider: ThemeProvider
  @State private var attributedStrings: [String: AttributedString] = [:]

  private var segnum: String? {
    SuttaRef.create(segment.scid)?.segnum
  }

  func bodyFont() -> Font {
    if segnum == "0.1" {
      return Font.title
    }
    if segnum == "0.2" {
      return Font.title2
    }

    return mlDoc.currentScid == segment.scid
      ? Font.title3
      : Font.body
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Segment number (above if needed)
      if layout.segmentNumberPosition == .above {
        Text(segnum ?? segment.scid)
          .font(.caption)
          .foregroundColor(themeProvider.theme.secondaryTextColor)
          .lineLimit(1)
          .padding(.horizontal)
      }

      // Columns container
      let columnsContent = HStack(
        alignment: .firstTextBaseline,
        spacing: layout.columnSpace,
      ) {
        // Segment number (left if needed)
        if layout.segmentNumberPosition == .left {
          Text(segnum ?? segment.scid)
            .font(.caption)
            .foregroundColor(themeProvider.theme.secondaryTextColor)
            .lineLimit(1)
            .frame(width: layout.segmentNumberWidth, alignment: .trailing)
        }

        // Pali column
        if Settings.shared.showPali {
          ColumnView(
            attributedString: attributedStrings["pali"],
            columnWidth: layout.columnWidth,
            bodyFont: bodyFont(),
          )
          .task {
            let text = getSegmentText(field: "pli")
            attributedStrings["pali"] = buildAttributedString(text)
          }
        }

        // Doc column
        if Settings.shared.showDoc {
          ColumnView(
            attributedString: attributedStrings["doc"],
            columnWidth: layout.columnWidth,
            bodyFont: bodyFont(),
          )
          .task {
            let text = getSegmentText(field: "doc")
            attributedStrings["doc"] = buildAttributedString(text)
          }
        }

        // Ref column
        if Settings.shared.showRef {
          ColumnView(
            attributedString: attributedStrings["ref"],
            columnWidth: layout.columnWidth,
            bodyFont: bodyFont(),
          )
          .task {
            let text = getSegmentText(field: "ref")
            attributedStrings["ref"] = buildAttributedString(text)
          }
        }
      }
      .foregroundColor(themeProvider.theme.textColor)
      .padding(.horizontal)

      // Wrap in ScrollView if horizontal scroll needed
      if layout.needsHorizontalScroll {
        ScrollView(.horizontal) {
          columnsContent
        }
      } else {
        columnsContent
      }
    }
    .padding(.vertical,
             isSegmentSelected ? 10 : 4)
    .background(
      isSegmentSelected ? themeProvider.theme
        .backgroundColor : .clear,
    )
    .overlay(
      RoundedRectangle(cornerRadius: 4)
        .stroke(
          isSegmentSelected ? themeProvider.theme
            .accentColor : .clear,
          style: StrokeStyle(
            lineWidth: 2,
            lineCap: .butt,
            lineJoin: .bevel,
            dash: [4, 3],
          ),
        ),
    )
    .id("\(segment.scid)-\(themeProvider.currentTheme)")
    .onTapGesture {
      mlDoc.currentScid = segment.scid
      if player.isPlaying {
        player.jumpToSegment(scid: segment.scid)
      }
      // Dismiss keyboard when segment is selected
      #if os(iOS)
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder),
          to: nil,
          from: nil,
          for: nil,
        )
      #endif
      cc.ok1(#line, "Selected segment:", segment.scid)
    }
  }

  private var isSegmentSelected: Bool {
    mlDoc.currentScid == segment.scid
  }

  private func getSegmentText(field: String = "doc") -> String {
    let EMPTY_SET = ""
    let value: String? = switch field.lowercased() {
    case "doc":
      segment.doc
    case "pli":
      segment.pli
    case "ref":
      segment.ref
    default:
      nil
    }
    return value?.isEmpty ?? true ? EMPTY_SET : value!
  }

  private func buildAttributedString(_ html: String) -> AttributedString {
    let parseResult = HTMLParser.parse(htmlString: html)
    var attributedString = AttributedString("")

    for span in parseResult.spans {
      var spanAttr = AttributedString(span.text)
      if span.isMatched {
        spanAttr.foregroundColor = themeProvider.theme.accentColor
      } else {
        spanAttr.foregroundColor = themeProvider.theme.textColor
      }
      attributedString.append(spanAttr)
    }

    return attributedString
  }
}

// MARK: - ColumnView Helper

private struct ColumnView: View {
  let attributedString: AttributedString?
  let columnWidth: CGFloat
  let bodyFont: Font
  @EnvironmentObject var themeProvider: ThemeProvider

  var body: some View {
    VStack(alignment: .leading) {
      if let attributedString, attributedString.characters.count > 0 {
        Text(attributedString)
          .font(bodyFont)
          .foregroundColor(themeProvider.theme.textColor)
          .lineLimit(nil)
      } else if attributedString == nil {
        Text("⏳")
          .font(bodyFont)
          .foregroundColor(themeProvider.theme.textColor)
      } else {
        VStack {
          Spacer()
          Image(systemName: "pencil.slash")
            .font(.title3)
            .foregroundColor(themeProvider.theme.secondaryTextColor)
            .frame(maxWidth: .infinity, alignment: .center)
          Spacer()
        }
      }
    }
    .frame(width: columnWidth, alignment: .topLeading)
  }
}

#Preview("SegmentView") {
  @Previewable @State var mlDoc = MLDocument(
    currentScid: "mn1:0.1",
  )

  let mockPlayer = SuttaPlayer()
  let layout = SegmentLayout.calculateLayout(
    availableWidth: 390,
    columnsShown: 1,
  )

  SegmentView(
    segment: Segment(scid: "mn1:0.1", doc: "The Middle Collection"),
    mlDoc: mlDoc,
    layout: layout,
    player: mockPlayer,
  )
  .environmentObject(ThemeProvider())
}
