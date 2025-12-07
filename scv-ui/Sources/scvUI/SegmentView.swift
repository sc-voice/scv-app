import scvCore
import SwiftUI
#if os(iOS)
  import UIKit
#endif

struct SegmentView: View {
  let cc = ColorConsole(#file, #function, dbg.SegmentView.other)
  let segment: Segment
  let mlDoc: MLDocument
  let player: SuttaPlayer
  let isCurrentlyPlaying: Bool

  @EnvironmentObject var themeProvider: ThemeProvider
  @State private var attributedString: AttributedString?

  private var segnum: String? {
    SuttaRef.create(segment.scid)?.segnum
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(segnum ?? segment.scid)
        .font(.caption)
        .foregroundColor(themeProvider.theme.secondaryTextColor)
        .lineLimit(1)

      if let attributedString {
        Text(attributedString)
          .font(.body)
          .lineLimit(nil)
      } else {
        ProgressView()
          .scaleEffect(0.8, anchor: .center)
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 4)
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
    .id(segment.scid)
    .onTapGesture {
      mlDoc.currentScid = segment.scid
      if isCurrentlyPlaying, player.isPlaying {
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
    .task {
      attributedString = buildAttributedString(getSegmentText())
    }
  }

  private var isSegmentSelected: Bool {
    mlDoc.currentScid == segment.scid
  }

  private func getSegmentText(field: String = "doc") -> String {
    let EMPTY_SET = "∅"
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

#Preview("SegmentView") {
  @Previewable @State var mlDoc = MLDocument(
    currentScid: "mn1:0.1",
  )

  let mockPlayer = SuttaPlayer()

  SegmentView(
    segment: Segment(scid: "mn1:0.1", doc: "The Middle Collection"),
    mlDoc: mlDoc,
    player: mockPlayer,
    isCurrentlyPlaying: false,
  )
  .environmentObject(ThemeProvider())
}
