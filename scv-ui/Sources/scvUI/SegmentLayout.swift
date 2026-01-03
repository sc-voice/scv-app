//
//  SegmentLayout.swift
//  scv-ui
//
//  Created by Claude on 2025-01-03.
//

import Foundation
#if os(iOS)
  import UIKit
  typealias PlatformFont = UIFont
#else
  import AppKit
  typealias PlatformFont = NSFont
#endif

// MARK: - Layout Constants

/// Maximum width for each column (Apple's readable content guide: 600pt / 2 columns)
public let MAX_COLUMN_WIDTH: CGFloat = 600

/// Minimum width for each column (usability constraint)
public let MIN_COLUMN_WIDTH: CGFloat = 200

/// Space between columns
public let COLUMN_SPACE: CGFloat = 8

struct SegmentLayout {
  enum SegmentNumberPosition {
    case left
    case above
    case hidden
  }

  let segmentNumberPosition: SegmentNumberPosition
  let columnWidth: CGFloat
  let columnSpace: CGFloat  // May be compressed from requested value
  let visibleColumnCount: Int
  let needsHorizontalScroll: Bool
  let totalContentWidth: CGFloat

  /// Measure text width for a given string and font
  /// - Parameters:
  ///   - text: The text to measure
  ///   - font: The font to use for measurement (default: 12pt system font)
  ///           Caller should pass dynamic font (e.g., UIFont.preferredFont(forTextStyle:))
  ///           to respect accessibility text size settings
  /// - Returns: The measured width in points
  static func calculateTextWidth(
    text: String,
    font: PlatformFont = PlatformFont.systemFont(ofSize: 12)
  ) -> CGFloat {
    let attributes = [NSAttributedString.Key.font: font]
    let size = (text as NSString).size(withAttributes: attributes)
    return size.width
  }

  /// Calculate layout for segments based on available space and column configuration
  /// - Parameters:
  ///   - availableWidth: Total width available for layout (screen width - safe area)
  ///   - columnsShown: Number of columns user wants to display (1-3)
  ///   - segmentNumberWidth: Measured width of the widest segment number in document (0 = hidden)
  ///   - maxColumnWidth: Maximum width per column
  ///   - minColumnWidth: Minimum width per column
  ///   - columnSpace: Space between columns
  /// - Returns: SegmentLayout with positioning and sizing information
  static func calculateLayout(
    availableWidth: CGFloat,
    columnsShown: Int = 1,
    segmentNumberWidth: CGFloat = 40,
    maxColumnWidth: CGFloat = MAX_COLUMN_WIDTH,
    minColumnWidth: CGFloat = MIN_COLUMN_WIDTH,
    columnSpace: CGFloat = COLUMN_SPACE
  ) -> SegmentLayout {
    // Step 1: Determine segment number position
    let segmentNumberPosition: SegmentNumberPosition
    if segmentNumberWidth == 0 {
      segmentNumberPosition = .hidden
    } else if segmentNumberWidth > 0.25 * minColumnWidth {
      segmentNumberPosition = .above
    } else {
      segmentNumberPosition = .left
    }

    // Step 2: Calculate available width for columns
    let availableForColumns: CGFloat
    switch segmentNumberPosition {
    case .left:
      availableForColumns = availableWidth - segmentNumberWidth - columnSpace
    case .above, .hidden:
      availableForColumns = availableWidth
    }

    // Step 3: Maximize visibleColumnCount (start with columnsShown, reduce if needed)
    var visibleColumnCount = min(columnsShown, 3) // Cap at 3 columns max
    var calculatedColumnWidth: CGFloat = 0

    for tryCount in stride(from: visibleColumnCount, through: 1, by: -1) {
      // Calculate column width for this count
      // spacingWidth includes padding on left, right, and between columns
      let spacingWidth = CGFloat(tryCount + 1) * columnSpace
      let columnWidth = (availableForColumns - spacingWidth) / CGFloat(tryCount)

      // Check if this width meets minimum requirement
      if columnWidth >= minColumnWidth {
        visibleColumnCount = tryCount
        calculatedColumnWidth = columnWidth
        break
      }
    }

    // Step 4: Maximize columnWidth (cap at maxColumnWidth)
    let columnWidth = min(calculatedColumnWidth, maxColumnWidth)

    // Step 5: Calculate totalContentWidth
    let totalContentWidth: CGFloat
    let columnSpacingWidth = CGFloat(visibleColumnCount + 1) * columnSpace
    switch segmentNumberPosition {
    case .left:
      totalContentWidth = segmentNumberWidth + columnSpace + (CGFloat(visibleColumnCount) * columnWidth) + columnSpacingWidth
    case .above, .hidden:
      totalContentWidth = (CGFloat(visibleColumnCount) * columnWidth) + columnSpacingWidth
    }

    // Step 6: Determine if horizontal scroll is needed
    let needsHorizontalScroll = visibleColumnCount < columnsShown

    return SegmentLayout(
      segmentNumberPosition: segmentNumberPosition,
      columnWidth: columnWidth,
      columnSpace: columnSpace,
      visibleColumnCount: visibleColumnCount,
      needsHorizontalScroll: needsHorizontalScroll,
      totalContentWidth: totalContentWidth
    )
  }
}
