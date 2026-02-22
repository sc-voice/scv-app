//
//  SegmentTests.swift
//  scv-core
//
//  Created by Claude on 2026-02-22.
//

import Foundation
@testable import scvCore
import Testing

@Suite
struct SegmentTests {
  // MARK: - SegmentType Tests

  @Test
  func segmentTypeHeaderStartsWithZero() {
    let segment = Segment(scid: "mn1:0.1")
    #expect(segment.type == .header)
  }

  @Test
  func segmentTypeHeaderWithZeroOnly() {
    let segment = Segment(scid: "dn1:0")
    #expect(segment.type == .header)
  }

  @Test
  func segmentTypeSectionEndsWithDotZero() {
    let segment = Segment(scid: "mn1:1.0")
    #expect(segment.type == .section)
  }

  @Test
  func segmentTypeSectionComplexNumber() {
    let segment = Segment(scid: "dn10:2.32.0")
    #expect(segment.type == .section)
  }

  @Test
  func segmentTypeParagraphEndsWithDotOne() {
    let segment = Segment(scid: "mn1:1.1")
    #expect(segment.type == .paragraph)
  }

  @Test
  func segmentTypeParagraphComplexNumber() {
    let segment = Segment(scid: "dn10:2.32.1")
    #expect(segment.type == .paragraph)
  }

  @Test
  func segmentTypeTextNormalSegment() {
    let segment = Segment(scid: "mn1:1.2")
    #expect(segment.type == .text)
  }

  @Test
  func segmentTypeTextMultipleDigits() {
    let segment = Segment(scid: "mn1:1.25")
    #expect(segment.type == .text)
  }

  @Test
  func segmentTypeTextNoColon() {
    let segment = Segment(scid: "mn1")
    #expect(segment.type == .text)
  }

  // MARK: - SegmentType Priority Tests

  @Test
  func headerTakesPriorityOverSection() {
    // "0.0" starts with 0, so it's header (not section)
    let segment = Segment(scid: "mn1:0.0")
    #expect(segment.type == .header)
  }

  @Test
  func headerTakesPriorityOverParagraph() {
    // "0.1" starts with 0, so it's header (not paragraph)
    let segment = Segment(scid: "mn1:0.1")
    #expect(segment.type == .header)
  }

  // MARK: - Full Segment Tests

  @Test
  func segmentWithDocText() {
    let segment = Segment(
      scid: "mn1:1.1",
      doc: "Translation text",
      matched: true,
    )
    #expect(segment.type == .paragraph)
    #expect(segment.isMatched == true)
    #expect(segment.displayText == "Translation text")
  }
}
