//
//  BackgroundPlayerView.swift
//  scv-ui
//
//  Created by Claude on 2026-02-10.
//

import scvCore
import SwiftUI

// MARK: - BackgroundPlayerView

/// Modal view for background playback with two phases: synthesis and playback.
///
/// **Synthesis Phase**: Shows circular progress modal with step counter, state
/// description,
/// time remaining estimate, and Cancel button. Uses polling (~0.5s intervals)
/// to update
/// progress from BackgroundPlayer.synthesisSnapshot.
///
/// **Playback Phase**: Shows minimal UI equivalent to lock screen playback
/// with:
/// - Play/Pause button
/// - Previous/Next segment buttons
/// - Current segment display (scid + text prefix)
/// - Horizontal progress bar
/// - Close (X) button
///
/// BackgroundPlayerView triggers BackgroundPlayer.prepare() on appear, which
/// orchestrates
/// segment synthesis. Once synthesis completes, view transitions to playback
/// UI.
public struct BackgroundPlayerView: View {
  @ObservedObject var player: BackgroundPlayer
  @Binding var isPresented: Bool
  let themeProvider: ThemeProvider

  @State private var pollingTask: Task<Void, Never>?
  @State private var isLoading = true
  @State private var errorMessage: String?

  let cc = ColorConsole(#file, #function, dbg.SuttaCardView.other)

  public init(
    player: BackgroundPlayer,
    isPresented: Binding<Bool>,
    themeProvider: ThemeProvider,
  ) {
    self.player = player
    _isPresented = isPresented
    self.themeProvider = themeProvider
  }

  public var body: some View {
    ZStack {
      themeProvider.theme.cardBackground.ignoresSafeArea()

      switch player.state {
      case .idle, .synthesizing:
        synthesisPhaseView
      case .paused, .playing, .done:
        playbackPhaseView
      case .cancelled, .failed:
        finalStateView
      }
    }
    .onAppear {
      startPreparation()
    }
    .onDisappear {
      stopPolling()
      // Cancel synthesis if still in progress
      if case .synthesizing = player.state {
        player.cancel()
      }
    }
  }

  // MARK: - Synthesis Phase View

  private var synthesisPhaseView: some View {
    VStack(spacing: 24) {
      // Header with sutta reference
      VStack(spacing: 8) {
        Text("synthesis.title".localized)
          .font(.headline)
          .foregroundColor(themeProvider.theme.textColor)
        if let snapshot = player.synthesisSnapshot {
          Text(snapshot.suttaRef.toString())
            .font(.caption)
            .foregroundColor(themeProvider.theme.secondaryTextColor)
        }
      }

      // Progress circle with step counter
      VStack(spacing: 12) {
        ZStack {
          Circle()
            .stroke(themeProvider.theme.borderColor, lineWidth: 8)
            .frame(width: 120, height: 120)

          if let snapshot = player.synthesisSnapshot, snapshot.totalSteps > 0 {
            Circle()
              .trim(
                from: 0,
                to: CGFloat(snapshot.currentStep) /
                  CGFloat(snapshot.totalSteps),
              )
              .stroke(
                themeProvider.theme.accentColor,
                style: StrokeStyle(lineWidth: 8, lineCap: .round),
              )
              .frame(width: 120, height: 120)
              .rotationEffect(.degrees(-90))
              .animation(.linear, value: snapshot.currentStep)
          }

          if let snapshot = player.synthesisSnapshot {
            Text("\(snapshot.currentStep)/\(snapshot.totalSteps)")
              .font(.system(.body, design: .monospaced))
              .foregroundColor(themeProvider.theme.textColor)
          } else {
            Text("0/0")
              .font(.system(.body, design: .monospaced))
              .foregroundColor(themeProvider.theme.secondaryTextColor)
          }
        }

        // State description
        if let snapshot = player.synthesisSnapshot {
          VStack(spacing: 8) {
            switch snapshot.state {
            case .synthesizing:
              Text("synthesis.synthesizing".localized)
                .font(.body)
                .foregroundColor(themeProvider.theme.secondaryTextColor)
              if let segment = snapshot.currentSegment {
                Text(segment.scid)
                  .font(.caption)
                  .foregroundColor(themeProvider.theme.secondaryTextColor)
              }
              // Time remaining
              let timeRemaining = snapshot.estimatedCompletion
                .timeIntervalSinceNow
              if timeRemaining > 0 {
                let minutes = Int(timeRemaining) / 60
                let seconds = Int(timeRemaining) % 60
                Text("synthesis.time_remaining"
                  .localized("\(minutes)m \(seconds)s"))
                  .font(.caption)
                  .foregroundColor(themeProvider.theme.secondaryTextColor)
              }
            case .completed:
              Text("synthesis.complete".localized)
                .font(.body)
                .foregroundColor(.green)
            case .cancelled:
              Text("synthesis.cancelled".localized)
                .font(.body)
                .foregroundColor(themeProvider.theme.secondaryTextColor)
            case let .failed(error):
              Text("synthesis.error".localized)
                .font(.body)
                .foregroundColor(themeProvider.theme.errorTextColor)
              Text(error)
                .font(.caption)
                .foregroundColor(themeProvider.theme.errorTextColor)
                .lineLimit(3)
            case .idle:
              Text("synthesis.starting".localized)
                .font(.body)
                .foregroundColor(themeProvider.theme.secondaryTextColor)
            }
          }
        }
      }

      // Action button
      let isSynthesizing = if case .synthesizing = player.state { true }
      else { false }
      Button(action: handleSynthesisButtonTap) {
        Text(isSynthesizing ? "synthesis.cancel".localized : "synthesis.done"
          .localized)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(isSynthesizing ? Color.red : themeProvider.theme
            .accentColor)
          .foregroundColor(.white)
          .cornerRadius(8)
      }

      Spacer()
    }
    .padding(24)
    .onAppear {
      startPolling()
    }
    .onDisappear {
      stopPolling()
    }
  }

  // MARK: - Playback Phase View

  private var playbackPhaseView: some View {
    VStack(spacing: 16) {
      // Close button
      HStack {
        Spacer()
        Button(action: { isPresented = false }) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundColor(themeProvider.theme.secondaryTextColor)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)

      Spacer()

      // Current segment display
      if let snapshot = player.playbackSnapshot {
        VStack(spacing: 12) {
          // Segment ID
          Text(snapshot.segment.scid)
            .font(.headline)
            .foregroundColor(themeProvider.theme.textColor)

          // Segment text preview (20 character prefix)
          let textPreview = (snapshot.segment.doc ?? "").prefix(60)
          Text(String(textPreview))
            .font(.body)
            .foregroundColor(themeProvider.theme.secondaryTextColor)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
      }

      Spacer()

      // Playback controls
      if let snapshot = player.playbackSnapshot {
        VStack(spacing: 20) {
          // Progress bar
          VStack(spacing: 8) {
            GeometryReader { geometry in
              ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                  .fill(themeProvider.theme.borderColor)

                // Progress fill
                let progress = snapshot.playbackDuration > 0
                  ? snapshot.elapsedPlaybackTime / snapshot.playbackDuration
                  : 0
                RoundedRectangle(cornerRadius: 4)
                  .fill(themeProvider.theme.accentColor)
                  .frame(width: geometry.size.width * progress)
              }
              .frame(height: 6)
            }
            .frame(height: 6)

            // Time display
            HStack {
              let elapsedMinutes = Int(snapshot.elapsedPlaybackTime) / 60
              let elapsedSeconds = Int(snapshot.elapsedPlaybackTime) % 60
              Text(String(format: "%d:%02d", elapsedMinutes, elapsedSeconds))
                .font(.caption)
                .foregroundColor(themeProvider.theme.secondaryTextColor)

              Spacer()

              let durationMinutes = Int(snapshot.playbackDuration) / 60
              let durationSeconds = Int(snapshot.playbackDuration) % 60
              Text(String(format: "%d:%02d", durationMinutes, durationSeconds))
                .font(.caption)
                .foregroundColor(themeProvider.theme.secondaryTextColor)
            }
          }

          // Play/Pause and navigation buttons
          HStack(spacing: 24) {
            // Previous button
            Button(action: { player.playPrevious() }) {
              Image(systemName: "chevron.left")
                .font(.title2)
                .foregroundColor(themeProvider.theme.textColor)
                .frame(minWidth: 44, minHeight: 44)
            }

            Spacer()

            // Play/Pause button
            let isPlaying = if case .playing = player.state { true }
            else { false }
            Button(action: { isPlaying ? player.pause() : player.play() }) {
              Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.title)
                .foregroundColor(.white)
                .frame(minWidth: 60, minHeight: 60)
                .background(themeProvider.theme.accentColor)
                .clipShape(Circle())
            }

            Spacer()

            // Next button
            Button(action: { player.playNext() }) {
              Image(systemName: "chevron.right")
                .font(.title2)
                .foregroundColor(themeProvider.theme.textColor)
                .frame(minWidth: 44, minHeight: 44)
            }
          }

          // Segment counter
          Text("synthesis.segment_count".localized(
            "\(snapshot.segmentIndex + 1)/\(snapshot.totalSegments)",
          ))
          .font(.caption)
          .foregroundColor(themeProvider.theme.secondaryTextColor)
        }
        .padding(.horizontal, 16)
      }

      Spacer()
    }
    .padding(.vertical, 16)
  }

  // MARK: - Final State View

  private var finalStateView: some View {
    VStack(spacing: 24) {
      let isCancelled = if case .cancelled = player.state { true }
      else { false }
      let errorMsg = player.state.failureMessage

      // Status icon and message
      VStack(spacing: 12) {
        if isCancelled {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 48))
            .foregroundColor(themeProvider.theme.secondaryTextColor)
          Text("synthesis.cancelled".localized)
            .font(.headline)
            .foregroundColor(themeProvider.theme.textColor)
        } else if let errorMsg {
          Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 48))
            .foregroundColor(themeProvider.theme.errorTextColor)
          Text("synthesis.error".localized)
            .font(.headline)
            .foregroundColor(themeProvider.theme.errorTextColor)
          Text(errorMsg)
            .font(.caption)
            .foregroundColor(themeProvider.theme.errorTextColor)
            .lineLimit(3)
        }
      }

      Spacer()

      // Close button
      Button(action: { isPresented = false }) {
        Text("synthesis.done".localized)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(themeProvider.theme.accentColor)
          .foregroundColor(.white)
          .cornerRadius(8)
      }
    }
    .padding(24)
  }

  // MARK: - Private Methods

  private func startPreparation() {
    cc.ok2(#line, "startPreparation()")
    Task {
      do {
        _ = try await player.prepare()
        cc.ok1(#line, "prepare() complete - ready for playback")
      } catch {
        cc.bad1(#line, "prepare() failed: \(error)")
        errorMessage = error.localizedDescription
      }
    }
  }

  private func startPolling() {
    cc.ok2(#line, "startPolling()")
    pollingTask = Task {
      while !Task.isCancelled, player.state == .synthesizing {
        // Poll happens automatically via @ObservedObject binding
        // Just sleep and let SwiftUI update via publisher
        try? await Task.sleep(nanoseconds: 500_000_000) // ~0.5s
      }
    }
  }

  private func stopPolling() {
    cc.ok2(#line, "stopPolling()")
    pollingTask?.cancel()
    pollingTask = nil
  }

  private func handleSynthesisButtonTap() {
    let isSynthesizing = if case .synthesizing = player.state { true }
    else { false }
    if isSynthesizing {
      player.cancel()
    } else {
      isPresented = false
    }
  }
}

// MARK: - Preview

#Preview("BackgroundPlayerView - Synthesis") {
  @Previewable @State var isPresented = true

  let suttaRef = SuttaRef.create("thig1.1/en/soma")!
  let player = BackgroundPlayer(suttaRef: suttaRef)

  BackgroundPlayerView(
    player: player,
    isPresented: $isPresented,
    themeProvider: ThemeProvider(),
  )
}
