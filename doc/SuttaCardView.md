# SuttaCardView Design

## Overview

SuttaCardView is the primary UI component for viewing and interacting with sutta (Buddhist scripture) documents. It provides:
- Multi-column segment display (Pali, document translation, references)
- Responsive layout calculations based on available width
- Audio playback controls via integrated SuttaPlayer
- Long-press gesture for background audio synthesis prefetch

## Architecture

### Component Hierarchy
```
CardView (container)
  └─ SuttaCardView<Card, Manager>
      ├─ Toolbar (title + play button)
      ├─ ScrollView (segments)
      │  └─ ForEach(segments)
      │     └─ SegmentView
      └─ SynthesisProgressModal (overlay, conditional)
```

### Dependencies
- **scvCore**: SuttaRef, Segment, AudioContext, AudioSynthesisSession, SessionSnapshot
- **SwiftUI**: Standard UI framework
- **SuttaPlayer**: Audio playback orchestration (injected via @ObservedObject)
- **ThemeProvider**: Theme colors and styling (@EnvironmentObject)

## State Management

### View State
```swift
@State private var segments: [Segment] = []           // Loaded segments from mlDoc
@State private var layout: SegmentLayout?             // Calculated layout metrics
@State private var availableWidth: CGFloat = 0        // Container width (from GeometryReader)
@State private var toolbarTitle: String = ""          // Currently unused (reserved)
```

### Synthesis State
```swift
@State private var backgroundSession: AudioSynthesisSession?    // Actor reference for synthesis
@State private var showSynthesisModal = false                   // Modal visibility toggle
```

**Invariants**:
- `backgroundSession` and `showSynthesisModal` lifecycle: session created → modal shown → session completes → modal dismissed
- Modal polls `session.value` for progress updates (no callback-based throttling needed)

## Gesture Handling

### Long-Press on Play Button

**Trigger**: User long-presses play button (line 135-149)

**Action**: Calls `startSynthesis()`
```swift
.onLongPressGesture {
  startSynthesis()
}
```

**Coexistence**: `.onLongPressGesture` coexists with Button's `action` closure (tap plays/pauses). Only long-press initiates synthesis.

## Audio Synthesis Integration

### Session Lifecycle

1. **Creation** (startSynthesis):
   - Create AudioSynthesisSession with suttaRef and optional progressCallback (for state transitions) or no callback (for polling-only approach)
   - Store reference in @State
   - Show modal (showSynthesisModal = true)

2. **Execution** (Task/await):
   - Call `await backgroundSession?.execute()` on background thread
   - Session synthesizes segments sequentially
   - If using callback: fires on state changes (actor thread, requires marshaling)
   - If using polling: modal queries session.value on main thread (see Progress Monitoring Patterns)

3. **Completion**:
   - Final snapshot has state = .completed, .cancelled, or .failed
   - UI updates reflect final state
   - User can dismiss modal

4. **Cleanup** (.onDisappear):
   - If SuttaCardView dismissed mid-synthesis, cancel session
   - Prevents orphaned background tasks

### Progress Monitoring Patterns

**Two approaches** (see AudioSynthesisSession.md "Progress Monitoring Patterns"):

1. **Callbacks** (state transitions):
   - Optional: `progressCallback` fires when state changes (.idle→.synthesizing, .synthesizing→.completed/cancelled/failed)
   - Use case: Auto-dismiss modal on completion, handle error states
   - Threading: Callback fires from actor thread; must marshal @State updates via DispatchQueue.main.async
   - Example:
   ```swift
   progressCallback: { snapshot in
     if snapshot.state == .completed || case .failed = snapshot.state {
       DispatchQueue.main.async {
         self.showSynthesisModal = false
       }
     }
   }
   ```

2. **Polling** (progress granularity, RECOMMENDED):
   - Modal polls `session.value` on ~0.5s timer for smooth progress updates
   - Use case: Display currentStep/totalSteps, estimatedCompletion during synthesis
   - Threading: Polling from main thread; actor handles concurrency, no marshaling needed
   - Advantage: Simpler (no throttling logic), fresh data always available
   - Example:
   ```swift
   Task {
     while !Task.isCancelled {
       let snapshot = await backgroundSession?.value
       self.displayProgress(snapshot)
       try? await Task.sleep(nanoseconds: 500_000_000)  // ~0.5s
     }
   }
   ```

**Design choice for SuttaCardView**: Use polling for modal progress display (keeps UI responsive without callback overhead). Optionally use callback for state-change notifications (e.g., auto-dismiss on completion).

## Modal Progress Display

### State Information
Modal displays SessionSnapshot fields:
- `currentStep` / `totalSteps` — Segment progress (e.g., "523/1167")
- `estimatedCompletion` — Time-based ETA
- `state` — Current synthesis state (.synthesizing, .completed, .cancelled, .failed)

### UI Design
- Circular progress bar showing currentStep/totalSteps ratio
- Segment count in center (e.g., "523/1167")
- Label below progress (synthesis state description)
- Button below label:
  - "Cancel" during synthesis (state == .synthesizing)
  - "Done" when complete (state == .completed, .cancelled, or .failed)

### Dismissal Paths
1. **Swipe-to-dismiss** — Default SwiftUI sheet behavior
2. **Cancel button tap** — During synthesis (state == .synthesizing)
3. **Done button tap** — After completion

All paths trigger `.onDisappear` hook which cancels session if still synthesizing.

## Layout Calculations

### Segment Layout
SegmentLayout calculates column widths and spacing based on:
- `availableWidth` — Container width from GeometryReader
- `columnsShown` — Count of visible columns (showPali, showDoc, showRef)
- `segmentNumberWidth` — Width of widest segment number

### Responsiveness
Layout recalculates on:
- `onAppear` — Initial layout
- `availableWidth` changes (GeometryReader callback)
- Settings changes (showPali, showDoc, showRef, maxColumnWidth)
- Segment count changes (onChange)

## Scrolling & Navigation

### Automatic Scroll
On appearance and when currentScid changes:
- Scroll to segment at `mlDoc.currentScid`
- Anchor point: two line heights from top (0.06 vertical)
- Animation: `.easeInOut(duration: 0.8)` if motion not reduced

### ScrollViewReader
Allows targeting specific segment by `scid` ID for positioning.

## Lifecycle Hooks

### onAppear
- Load segments from mlDoc
- Calculate initial layout
- Initialize currentScid if nil

### onDisappear
- Stop playback if this sutta is currently playing
- Cancel background synthesis session (if mid-synthesis)
- Clear currentSutta from player to prevent crashes on deletion

```swift
.onDisappear {
  if player.currentSutta?.sutta_uid == card.mlDoc?.sutta_uid {
    player.pause()
    player.currentSutta = nil
  }
  Task {
    await backgroundSession?.cancel()
  }
}
```

## Styling & Theme

- **Toolbar**: ThemeProvider.theme.toolbarBackground and toolbarForeground
- **Segments**: ThemeProvider.theme.cardBackground
- **Play button color**: Green when synthesizer speaking, else toolbarForeground
- **Font sizes**: Title2 for play button, Body for text

**Accessibility**:
- Play button labeled with localized accessibility strings
- Segment numbers and text accessible via SegmentView

## Related Documentation

- `doc/AudioSynthesisSession.md` — Synthesis actor API, Progress Monitoring Patterns (callbacks vs polling), and SwiftUI integration
- `doc/BackgroundAudio.md` — UX requirements, progress UI design, and threading considerations
- `doc/SuttaPlayer.md` — Audio playback integration
- `scv-ui/Sources/scvUI/SegmentView.swift` — Segment display details
- `scv-ui/Sources/scvUI/SegmentLayout.swift` — Layout calculation engine
