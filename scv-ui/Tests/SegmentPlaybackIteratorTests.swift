//
//  SegmentPlaybackIteratorTests.swift
//  scv-ui
//
//  Unit tests for SegmentPlaybackIterator AsyncIterator
//

import Foundation
import scvCore
import Testing

@testable import scvUI

// MARK: - Mock AudioEffects

/// Mock implementation of IAudioEffects for testing
@MainActor
final class MockAudioEffects: IAudioEffects {
  var announcedEvents: [AudioEvent] = []
  var cancelCalled: Bool = false

  func announce(_ event: AudioEvent) {
    announcedEvents.append(event)
  }

  func announceAsync(_ event: AudioEvent) async {
    announcedEvents.append(event)
  }

  func cancel() {
    cancelCalled = true
    announcedEvents.append(.pause)
  }

  func reset() {
    announcedEvents = []
    cancelCalled = false
  }
}

// MARK: - SegmentPlaybackIteratorTests

@Suite
struct SegmentPlaybackIteratorTests {
  @MainActor
  @Test("Basic iteration returns all segments in order")
  func basicIteration() async {
    // Given
    let segments = [
      Segment(scid: "mn1:1.2", doc: "First segment"),
      Segment(scid: "mn1:1.3", doc: "Second segment"),
      Segment(scid: "mn1:1.4", doc: "Third segment"),
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    let result = await [
      iterator.next(),
      iterator.next(),
      iterator.next(),
      iterator.next(),
    ]

    // Then
    #expect(result.count == 4)
    #expect(result[0]?.segment.scid == "mn1:1.2")
    #expect(result[0]?.index == 0)
    #expect(result[1]?.segment.scid == "mn1:1.3")
    #expect(result[1]?.index == 1)
    #expect(result[2]?.segment.scid == "mn1:1.4")
    #expect(result[2]?.index == 2)
    #expect(result[3] == nil)
  }

  @MainActor
  @Test("Skips empty segments and announces .noText")
  func skipEmptySegments() async {
    // Given
    let segments = [
      Segment(scid: "mn1:0.1", doc: "First"),
      Segment(scid: "mn1:0.2", doc: ""), // Empty
      Segment(scid: "mn1:0.3", doc: ""), // Empty
      Segment(scid: "mn1:0.4", doc: "Third"),
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    let result1 = await iterator.next()
    let result2 = await iterator.next()
    let result3 = await iterator.next()

    // Then
    #expect(result1?.segment.scid == "mn1:0.1")
    #expect(result1?.index == 0)
    #expect(result2?.segment.scid == "mn1:0.4")
    #expect(result2?.index == 3)
    #expect(result3 == nil)

    // Verify .noText was announced for skipped empty segments
    let noTextCount = mockAudioEffects.announcedEvents
      .count(where: { $0 == .noText })
    #expect(noTextCount == 2)
  }

  @MainActor
  @Test("Announces .header on 0.1 segment")
  func headerAnnouncementOn01() async {
    // Given
    let segments = [
      Segment(scid: "mn1:0.1", doc: "First"),
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    _ = await iterator.next()

    // Then
    #expect(mockAudioEffects.announcedEvents.contains(.header))
  }

  @MainActor
  @Test("Announces .endSutta after exhausting segments")
  func endSuttaAnnouncementOnLast() async {
    // Given
    let segments = [
      Segment(scid: "mn1:0.1", doc: "Only"),
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    _ = await iterator.next() // Get segment
    _ = await iterator.next() // Triggers .endSutta

    // Then
    #expect(mockAudioEffects.announcedEvents.contains(.endSutta))
  }

  @MainActor
  @Test("Non-0.1 headers announce nothing")
  func noAnnouncementForOtherHeaders() async {
    // Given
    let segments = [
      Segment(scid: "mn1:0.1", doc: "First"),
      Segment(scid: "mn1:0.2", doc: "Second"),
      Segment(scid: "mn1:0.3", doc: "Third"),
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    _ = await iterator.next() // First (0.1)
    mockAudioEffects.reset()
    _ = await iterator.next() // Second (0.2)
    let eventsAfterSecond = mockAudioEffects.announcedEvents

    // Then - Second segment (0.2) should have no announcement
    #expect(eventsAfterSecond.isEmpty)
  }

  @MainActor
  @Test("cancel() stops iteration")
  func cancelStopsIteration() async {
    // Given
    let segments = [
      Segment(scid: "mn1:0.1", doc: "First"),
      Segment(scid: "mn1:0.2", doc: "Second"),
      Segment(scid: "mn1:0.3", doc: "Third"),
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    _ = await iterator.next() // Get first segment
    iterator.cancel()
    let afterCancel = await iterator.next()

    // Then
    #expect(afterCancel == nil)
    #expect(mockAudioEffects.cancelCalled)
  }

  @MainActor
  @Test("Empty segments at end returns nil")
  func emptySegmentsAtEnd() async {
    // Given
    let segments = [
      Segment(scid: "mn1:0.1", doc: "First"),
      Segment(scid: "mn1:0.2", doc: ""), // Empty
      Segment(scid: "mn1:0.3", doc: ""), // Empty
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    let result1 = await iterator.next()
    let result2 = await iterator.next()

    // Then
    #expect(result1?.segment.scid == "mn1:0.1")
    #expect(result1?.index == 0)
    #expect(result2 == nil)
  }

  @MainActor
  @Test("All empty segments returns nil on first call")
  func allEmptySegments() async {
    // Given
    let segments = [
      Segment(scid: "mn1:0.1", doc: ""),
      Segment(scid: "mn1:0.2", doc: ""),
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    let result = await iterator.next()

    // Then
    #expect(result == nil)
    let noTextCount = mockAudioEffects.announcedEvents
      .count(where: { $0 == .noText })
    #expect(noTextCount == 2)
  }

  @MainActor
  @Test("Segment without textKey property is skipped")
  func skipSegmentWithoutTextKey() async {
    // Given
    let segments = [
      Segment(scid: "mn1:0.1", doc: nil, ref: nil, pli: "Pali text"),
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    let result = await iterator.next()

    // Then - segment skipped because doc is nil/empty
    #expect(result == nil)
    #expect(mockAudioEffects.announcedEvents.contains(.noText))
  }

  @MainActor
  @Test("Single segment announces .header and .endSutta")
  func singleSegmentAnnouncesHeaderAndEnd() async {
    // Given
    let segments = [
      Segment(scid: "mn1:0.1", doc: "Only segment"),
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    _ = await iterator.next() // Get segment
    _ = await iterator.next() // Triggers .endSutta

    // Then
    #expect(mockAudioEffects.announcedEvents.contains(.header))
    #expect(mockAudioEffects.announcedEvents.contains(.endSutta))
  }

  @MainActor
  @Test("Multiple iterations return nil consistently")
  func multipleNilReturns() async {
    // Given
    let segments = [
      Segment(scid: "mn1:0.1", doc: "Only"),
    ]
    let mockAudioEffects = MockAudioEffects()
    let audioContext = AudioContext(for: "en")
    var iterator = SegmentPlaybackIterator(
      segments: segments,
      audioEffects: mockAudioEffects,
      audioContext: audioContext,
      textKey: "doc",
    )

    // When
    _ = await iterator.next()
    let nil1 = await iterator.next()
    let nil2 = await iterator.next()
    let nil3 = await iterator.next()

    // Then
    #expect(nil1 == nil)
    #expect(nil2 == nil)
    #expect(nil3 == nil)
  }
}
