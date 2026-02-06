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

  @Test("init creates session without callback")
  func initWithoutCallback() async {
    let suttaRef = SuttaRef.create("thig1.1/de/sabbamitta")!
    let session = AudioSynthesisSession(suttaRef)

    let value = await session.value

    #expect(value.suttaRef == suttaRef)
    #expect(value.state == .idle)
  }

  @Test("init creates session with suttaRef")
  func initWithSuttaRef() async {
    let suttaRef = SuttaRef.create("thig1.1/de/sabbamitta")!
    let session = AudioSynthesisSession(suttaRef, progressCallback: { _ in })

    let value = await session.value

    // Verify all snapshot members
    #expect(value.suttaRef == suttaRef)
    #expect(value.state == .idle)
    #expect(value.currentStep == 0)
    #expect(value.totalSteps == 0)
    #expect(value.currentSegment == nil)
    #expect(value.estimatedCompletion >= value.started)

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
    let session = AudioSynthesisSession(
      suttaRef,
      progressCallback: { _ in },
      audioContext: context,
    )

    let value = await session.value
    #expect(value.audioContext == context)
  }

  @Test("loadSuttaSegments loads segments for valid sutta via polling")
  func loadSuttaSegmentsValid() async {
    let suttaRef = SuttaRef.create("thig1.1/de/sabbamitta")!
    // No callback; verify polling works
    let session = AudioSynthesisSession(suttaRef)

    await session.loadSuttaSegments()

    // Poll for current value after loading
    let value = await session.value
    #expect(value.totalSteps > 0, "Should load segments for thig1.1")
    #expect(
      value.currentStep == 1,
      "currentStep should be STEP_LOAD_SEGMENTS after loading",
    )

    // Verify polling returns correct data
    #expect(
      value.totalSteps == 10,
      "Should have 10 total steps (1 load + 9 segments)",
    )

    // Verify currentSegment in snapshot with actual values
    #expect(
      value.currentSegment != nil,
      "currentSegment should be first segment in queue",
    )
    if let currentSeg = value.currentSegment {
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
    var lastSnapshot: SessionSnapshot?
    let session = AudioSynthesisSession(
      suttaRef,
      progressCallback: { snapshot in
        lastSnapshot = snapshot
      },
    )

    await session.loadSuttaSegments()

    let value = await session.value
    if case let .failed(errorMsg) = value.state {
      #expect(errorMsg.contains("no segments"))
    } else {
      #expect(Bool(false), "Expected state .failed, got \(value.state)")
    }
    #expect(value.currentSegment == nil)

    // Verify progressCallback was invoked with failed state
    #expect(
      lastSnapshot != nil,
      "progressCallback should have been invoked",
    )
    if case let .failed(errorMsg) = lastSnapshot?.state {
      #expect(errorMsg.contains("no segments"))
    } else {
      #expect(Bool(false), "Expected callback state .failed")
    }
  }

  @Test("cancel sets state to cancelled")
  func cancelSetsCancelledState() async {
    let suttaRef = SuttaRef.create("thig1.1/de/sabbamitta")!
    var lastSnapshot: SessionSnapshot?
    let session = AudioSynthesisSession(
      suttaRef,
      progressCallback: { snapshot in
        lastSnapshot = snapshot
      },
    )

    let cancelValue = await session.cancel()

    let value = await session.value
    #expect(
      value.state == .cancelled,
      "State should be .cancelled after cancel()",
    )

    // Verify cancelValue equals current session value
    #expect(
      cancelValue == value,
      "cancelValue should equal current session value",
    )

    // Verify callback was invoked with cancelled state
    #expect(lastSnapshot != nil, "progressCallback should have been invoked")
    #expect(
      lastSnapshot?.state == .cancelled,
      "Callback should have .cancelled state",
    )
    #expect(
      lastSnapshot == cancelValue,
      "Callback snapshot should equal cancelValue",
    )
  }

  @Test("INTEGRATION: execute() state-change callbacks fire at transitions")
  func executeStateChangeCallbacks() async {
    let suttaRef = SuttaRef.create("thig1.1/en/soma")!

    // Use persistent test audio store in local/build
    let projectRoot = projectRoot()
    let testAudioDir = projectRoot
      .appendingPathComponent("local/build/test-audio-store")
    try? FileManager.default.createDirectory(
      at: testAudioDir,
      withIntermediateDirectories: true,
    )
    let testStore = AudioStore.create(path: testAudioDir)

    // Track callbacks with thread-safe class
    final class CallbackTracker: Sendable {
      nonisolated(unsafe) var callbackCount = 0
      nonisolated(unsafe) var stateTransitions: [SynthesisState] = []
      nonisolated(unsafe) var finalSnapshot: SessionSnapshot?
    }
    let tracker = CallbackTracker()

    let startTime = Date()

    let finalValue = await AudioSynthesisSession(
      suttaRef,
      progressCallback: { snapshot in
        tracker.callbackCount += 1
        tracker.stateTransitions.append(snapshot.state)
        tracker.finalSnapshot = snapshot
      },
      audioStore: testStore,
    ).execute()

    let elapsedSeconds = Date().timeIntervalSince(startTime)

    // Verify execution completed
    #expect(finalValue.state == .completed, "Final state should be .completed")
    #expect(
      tracker.finalSnapshot?.state == .completed,
      "Last callback should have .completed state",
    )

    // Verify sparse callbacks: only state transitions
    // Expected: idle→synthesizing, synthesizing→completed (2 transitions minimum)
    #expect(
      tracker.callbackCount >= 2,
      "Should fire at least 2 state-transition callbacks",
    )
    #expect(
      tracker.callbackCount < 20,
      "Should have sparse callbacks (not per-segment)",
    )

    // Verify state progression
    #expect(
      tracker.stateTransitions.contains(.synthesizing),
      "Should transition through .synthesizing",
    )
    #expect(
      tracker.stateTransitions.last == .completed,
      "Last state transition should be .completed",
    )

    // Verify steps advanced (polling shows progress)
    #expect(finalValue.currentStep > 0, "Should have advanced steps")
    #expect(
      finalValue.currentStep == finalValue.totalSteps,
      "All steps should be completed",
    )

    cc.ok1(
      #line,
      #function,
      "✅ Synthesis completed: \(finalValue.currentStep) steps in \(String(format: "%.2f", elapsedSeconds))s",
    )
    cc.ok1(#line, #function, "Audio stored at: \(testAudioDir.path)")
    cc.ok1(
      #line,
      #function,
      "State callbacks: \(tracker.callbackCount), Transitions: \(tracker.stateTransitions)",
    )
  }

  @Test("INTEGRATION: polling returns fresh progress without callbacks")
  func executePollingWithoutCallback() async {
    let suttaRef = SuttaRef.create("thig1.1/en/soma")!

    // Use persistent test audio store
    let projectRoot = projectRoot()
    let testAudioDir = projectRoot
      .appendingPathComponent("local/build/test-audio-store-polling")
    try? FileManager.default.createDirectory(
      at: testAudioDir,
      withIntermediateDirectories: true,
    )
    let testStore = AudioStore.create(path: testAudioDir)

    let session = AudioSynthesisSession(
      suttaRef,
      audioStore: testStore,
    ) // No callback

    let startTime = Date()

    // Execute synthesis
    let finalValue = await session.execute()

    let elapsedSeconds = Date().timeIntervalSince(startTime)

    // Verify completion via polling final value
    #expect(finalValue.state == .completed, "Final state should be .completed")

    // Verify progress via polling
    #expect(finalValue.currentStep > 0, "Should have advanced steps via polling")
    #expect(
      finalValue.currentStep == finalValue.totalSteps,
      "All steps should be completed",
    )

    cc.ok1(
      #line,
      #function,
      "✅ Polling synthesis completed: \(finalValue.currentStep) steps in \(String(format: "%.2f", elapsedSeconds))s",
    )
  }
}
