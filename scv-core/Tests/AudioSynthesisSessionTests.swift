//
//  AudioSynthesisSessionTests.swift
//  scv-coreTests
//
//  Created by Claude on 2026-02-04.
//

import Foundation
@testable import scvCore
import Testing

@Suite struct AudioSynthesisSessionTests {
  let cc = ColorConsole(#file, #function, dbg.AudioSynthesisSession.other)

  @Test("init creates session with suttaRef")
  func initWithSuttaRef() async {
    let suttaRef = SuttaRef.create("thig1.1/de/sabbamitta")!
    let session = AudioSynthesisSession(suttaRef)

    let value = await session.getValue()

    // Verify all snapshot members
    #expect(value.suttaRef == suttaRef)
    #expect(value.state == .idle)
    #expect(value.currentStep == 0)
    #expect(value.totalSteps == 0)
    #expect(value.currentSegment == nil)
    #expect(value.estimatedTimeRemaining >= 0)

    // Verify AudioContext language defaults to suttaRef.lang
    let defaultContext = AudioContext(for: suttaRef.lang)
    #expect(value.audioContext == defaultContext)

    // Verify started is recent (within last second)
    let timeSinceStart = Date().timeIntervalSince(value.started)
    #expect(timeSinceStart >= 0 && timeSinceStart < 1.0)
  }

  @Test("init uses provided audioContext")
  func initWithAudioContext() async {
    let suttaRef = SuttaRef.create("thig1.1/de/sabbamitta")!
    let context = AudioContext(for: "de")
    let session = AudioSynthesisSession(suttaRef, audioContext: context)

    let value = await session.getValue()
    #expect(value.audioContext == context)
  }

  @Test("loadSuttaSegments loads segments for valid sutta")
  func loadSuttaSegmentsValid() async {
    let suttaRef = SuttaRef.create("thig1.1/de/sabbamitta")!
    let session = AudioSynthesisSession(suttaRef)

    await session.setTestProgressCallback { _ in }
    await session.loadSuttaSegments()

    let value = await session.getValue()
    #expect(value.totalSteps > 0, "Should load segments for thig1.1")
    #expect(
      value.currentStep == 1,
      "currentStep should be STEP_LOAD_SEGMENTS after loading",
    )

    // Verify progressCallback was invoked with correct data
    let callbackSnapshot = await session.getLastCallbackSnapshot()
    #expect(
      callbackSnapshot != nil,
      "progressCallback should have been invoked",
    )
    #expect(callbackSnapshot?.currentStep == 1)
    #expect(callbackSnapshot?
      .totalSteps == 10) // STEP_LOAD_SEGMENTS(1) + 9 segments

    // Verify currentSegment in snapshot with actual values
    #expect(
      callbackSnapshot?.currentSegment != nil,
      "currentSegment should be first segment in queue",
    )
    if let currentSeg = callbackSnapshot?.currentSegment {
      // First segment of thig1.1/de/sabbamitta is "thig1.1:0.1"
      #expect(
        currentSeg.scid == "thig1.1:0.1",
        "First segment should be thig1.1:0.1",
      )

      // First segment contains the heading in German
      #expect(
        currentSeg.doc?.contains("Strophen der altehrwürdigen Nonnen") == true,
        "First segment should contain title text",
      )
      #expect(currentSeg.doc?.contains("1.1") == true,
              "First segment should contain reference number")
    }
  }

  @Test("loadSuttaSegments sets failed state for sutta with no segments")
  func loadSuttaSegmentsEmptyRef() async {
    // mn1/en/soma is a valid sutta ref but author soma has no data for it
    let suttaRef = SuttaRef.create("mn1/en/soma")!
    let session = AudioSynthesisSession(suttaRef)

    await session.setTestProgressCallback { _ in }
    await session.loadSuttaSegments()

    let value = await session.getValue()
    if case let .failed(errorMsg) = value.state {
      #expect(errorMsg.contains("no segments"))
    } else {
      #expect(Bool(false), "Expected state .failed, got \(value.state)")
    }
    #expect(value.currentSegment == nil)

    // Verify progressCallback was invoked with failed state
    let callbackSnapshot = await session.getLastCallbackSnapshot()
    #expect(
      callbackSnapshot != nil,
      "progressCallback should have been invoked",
    )
    if case let .failed(errorMsg) = callbackSnapshot?.state {
      #expect(errorMsg.contains("no segments"))
    } else {
      #expect(Bool(false), "Expected callback state .failed")
    }
  }
}
