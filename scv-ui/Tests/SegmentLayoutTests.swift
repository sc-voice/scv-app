//
//  SegmentLayoutTests.swift
//  scv-ui
//
//  Created by Claude on 2025-01-03.
//

import Foundation
@testable import scvUI
import Testing

@Suite
struct SegmentLayoutTests {
  let cc = ColorConsole(#file, #function, dbg.scvUITests.other)

  // MARK: - calculateTextWidth Tests

  @Test
  func calculateTextWidthForShortSegmentNumber() {
    let width = SegmentLayout.calculateTextWidth(text: "mn1:0.1")
    #expect(width > 0)
    #expect(width < 60, "Short segment number should be < 60pt")
    cc.ok1(#line, "width: \(width)")
  }

  @Test
  func calculateTextWidthForLongVinayaReference() {
    let width = SegmentLayout
      .calculateTextWidth(text: "pli-tv-bu-vb-pt:1.1.1.1")
    #expect(width > 100, "Long Vinaya reference should be > 100pt")
    cc.ok1(#line, "width: \(width)")
  }

  // MARK: - calculateLayout Tests: iPhone

  @Test
  func calculateLayoutForIPhone430WithOneColumn() {
    // iPhone 16 Pro Max: 430pt width, 1 column shown, long Vinaya reference
    let layout = SegmentLayout.calculateLayout(
      availableWidth: 430,
      columnsShown: 1,
      segmentNumberWidth: 190,
    )

    // segmentNumberWidth 190 > 0.35 * 200 (70), so position = .above
    // Available for column: 430pt (entire width)
    // spacingWidth = (1 + 1) * 8 = 16pt (left + right padding)
    // Column width: (430 - 16) / 1 = 414, but capped at MAX_COLUMN_WIDTH (600)
    #expect(layout.segmentNumberPosition == .above,
            "Should place segment number above (width 190 > 35% of 200)")
    #expect(
      layout.columnWidth == 414,
      "Column width should account for left/right padding",
    )
    #expect(layout.visibleColumnCount == 1)
    #expect(layout.needsHorizontalScroll == false)
    cc.ok1(#line, "columnWidth: \(layout.columnWidth)")
  }

  @Test
  func calculateLayoutForIPhone390WithOneColumn() {
    // iPhone 14/15: 390pt width, 1 column shown
    let layout = SegmentLayout.calculateLayout(
      availableWidth: 390,
      columnsShown: 1,
      segmentNumberWidth: 40,
    )

    // With segment number width 40pt > 10% of 390 (39pt), position = .above
    // Available: 390pt (entire width)
    // spacingWidth = (1 + 1) * 8 = 16pt (left + right padding)
    // Column width: (390 - 16) / 1 = 374pt
    #expect(layout.segmentNumberPosition == .above,
            "Should place segment number above on 390pt screen")
    #expect(
      layout.columnWidth == 374,
      "Column width should account for padding",
    )
    #expect(layout.visibleColumnCount == 1)
    cc.ok1(#line, "columnWidth: \(layout.columnWidth)")
  }

  @Test
  func calculateLayoutForNarrowScreenPlacesSegmentAbove() {
    // Narrow screen: 300pt width, might not have room for segnum on left
    let layout = SegmentLayout.calculateLayout(
      availableWidth: 300,
      columnsShown: 1,
      segmentNumberWidth: 150,
    )

    // segmentNumberWidth 150 > 10% of 300 (30), so position = .above
    // Available: 300pt for column
    // spacingWidth = (1 + 1) * 8 = 16pt
    // Column width: (300 - 16) / 1 = 284pt
    #expect(layout.segmentNumberPosition == .above,
            "Should place segment number above (width 150 > 10% of 300)")
    #expect(
      layout.columnWidth == 284,
      "Column width should account for padding",
    )
    cc.ok1(#line, "columnWidth: \(layout.columnWidth)")
  }

  // MARK: - calculateLayout Tests: iPad

  @Test
  func calculateLayoutForIPadPortraitWithTwoColumns() {
    // iPad portrait: 768pt width, 2 columns shown
    let layout = SegmentLayout.calculateLayout(
      availableWidth: 768,
      columnsShown: 2,
      segmentNumberWidth: 40,
      maxColumnWidth: 360,
      minColumnWidth: 200,
      columnSpace: 8,
    )

    // With 2 columns: available = 768 - 40 (segnum) - 8 (space) - 8
    // (inter-column) = 712pt
    // Each column: 712 / 2 = 356pt
    #expect(layout.segmentNumberPosition == .left,
            "iPad should have room for segnum on left")
    #expect(layout.visibleColumnCount == 2 || layout.visibleColumnCount == 1,
            "Should show 1-2 columns")
    #expect(layout.columnWidth <= 360, "Should respect maxColumnWidth")
    cc.ok1(
      #line,
      "columnWidth: \(layout.columnWidth), visibleCount: \(layout.visibleColumnCount)",
    )
  }

  @Test
  func calculateLayoutForIPadLandscapeWithThreeColumns() {
    // iPad landscape: 1366pt width, 3 columns shown
    let layout = SegmentLayout.calculateLayout(
      availableWidth: 1366,
      columnsShown: 3,
      segmentNumberWidth: 40,
      maxColumnWidth: 360,
      minColumnWidth: 200,
      columnSpace: 8,
    )

    #expect(layout.segmentNumberPosition == .left,
            "iPad landscape should have room for segnum on left")
    #expect(layout.visibleColumnCount >= 2,
            "iPad landscape should show at least 2 columns")
    #expect(layout.columnWidth <= 360, "Should respect maxColumnWidth")
    cc.ok1(
      #line,
      "columnWidth: \(layout.columnWidth), visibleCount: \(layout.visibleColumnCount)",
    )
  }

  // MARK: - calculateLayout Tests: Edge Cases

  @Test
  func calculateLayoutWithMinimalWidth() {
    // Very narrow: 200pt, 1 column
    let layout = SegmentLayout.calculateLayout(
      availableWidth: 200,
      columnsShown: 1,
      segmentNumberWidth: 0,
      maxColumnWidth: 360,
      minColumnWidth: 100,
      columnSpace: 0,
    )

    #expect(layout.columnWidth <= 200)
    #expect(layout.columnWidth >= 100, "Should respect minColumnWidth")
    cc.ok1(#line, "columnWidth: \(layout.columnWidth)")
  }

  @Test
  func calculateLayoutWithMultipleColumnsNarrowWidth() {
    // Narrow screen requesting 2 columns: 300pt width
    let layout = SegmentLayout.calculateLayout(
      availableWidth: 300,
      columnsShown: 2,
      segmentNumberWidth: 40,
      maxColumnWidth: 360,
      minColumnWidth: 100,
      columnSpace: 8,
    )

    // May need to reduce visible columns if they don't fit
    #expect(layout.visibleColumnCount >= 1, "Should show at least 1 column")
    #expect(layout.columnWidth >= 100, "Should respect minColumnWidth")
    cc.ok1(
      #line,
      "columnWidth: \(layout.columnWidth), visibleCount: \(layout.visibleColumnCount)",
    )
  }
}
