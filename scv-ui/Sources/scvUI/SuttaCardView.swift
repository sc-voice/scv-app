//
//  SuttaCardView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-01.
//

import scvCore
import SwiftUI
#if os(iOS)
  import UIKit
#endif

// MARK: - SuttaCardView

/// Sutta viewer card displaying mlDoc segments with selection and highlighting
public struct SuttaCardView<Card: ICard, Manager: ICardManager>: View
  where Manager.ManagedCard == Card
{
  #if os(iOS)
    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
  #else
    let isPhone = false
  #endif
  @Binding var card: Card
  let cardManager: Manager
  @EnvironmentObject var themeProvider: ThemeProvider
  @ObservedObject var player: SuttaPlayer
  @State private var segments: [Segment] = []
  @State private var layout: SegmentLayout?
  @State private var availableWidth: CGFloat = 0
  @State private var toolbarTitle: String = ""
  @State private var backgroundSession: AudioSynthesisSession?
  @State private var showSynthesisModal = false
  @State private var currentSnapshot: SessionSnapshot?
  @State private var lastProgressUpdateTime = Date.distantPast
  let cc = ColorConsole(#file, #function, dbg.SuttaCardView.other)
  @Environment(\.accessibilityReduceMotion) var reduceMotion

  private var suttaRef: SuttaRef? {
    SuttaRef.create(card.suttaReference)
  }

  private var isSuttaCentral: Bool {
    guard let mlDoc = card.mlDoc else { return false }
    let dbInfo = DatabaseManifest.shared.info(
      language: mlDoc.docLang,
      author: mlDoc.docAuthor,
    )
    guard let authorBaseUrl = dbInfo?.authorBaseUrl else { return false }
    return authorBaseUrl.lowercased().contains("suttacentral")
  }

  private var title: String {
    var abbr: String?

    if let mlDoc = card.mlDoc, let currentScid = mlDoc.currentScid {
      if let currentRef = SuttaRef.create(currentScid) {
        abbr = currentRef.abbreviation()
      }
    }
    if abbr == nil {
      abbr = suttaRef?.abbreviation() ?? "suttaRef?"
    }

    if isSuttaCentral {
      return "SuttaCentral \(abbr ?? "")"
    }
    return abbr ?? "suttaRef?"
  }

  public init(
    card: Binding<Card>,
    cardManager: Manager,
    player: SuttaPlayer = .shared,
  ) {
    _card = card
    self.cardManager = cardManager
    self.player = player
  }

  func calcSegmentNumberWidth() -> CGFloat {
    let lastScid = segments.last?.scid ?? ""
    let segmentNumberWidth = SegmentLayout.calculateTextWidth(
      text: lastScid,
      font: PlatformFont.systemFont(ofSize: 12),
    )
    return segmentNumberWidth
  }

  func updateLayout() {
    guard availableWidth > 0, !segments.isEmpty else { return }
    let segmentNumberWidth = calcSegmentNumberWidth()
    let columnsShown = (Settings.shared.showPali ? 1 : 0) +
      (Settings.shared.showDoc ? 1 : 0) +
      (Settings.shared.showRef ? 1 : 0)

    layout = SegmentLayout.calculateLayout(
      availableWidth: availableWidth,
      columnsShown: max(1, columnsShown),
      segmentNumberWidth: segmentNumberWidth,
    )
  }

  private var suttaCentralUrl: URL? {
    guard isSuttaCentral, let mlDoc = card.mlDoc else { return nil }
    let urlString = "https://suttacentral.net/\(mlDoc.sutta_uid)/\(mlDoc.docLang)/\(mlDoc.docAuthor)"
    return URL(string: urlString)
  }

  private func applySuttaModifiers(_ view: some View) -> some View {
    let step1 = view
      .toolbar {
        ToolbarItem(placement: .principal) {
          HStack {
            VStack(spacing: 0) {
              if isSuttaCentral, let url = suttaCentralUrl {
                Link(title, destination: url)
                  .font(.headline)
                  .lineLimit(nil)
                  .foregroundColor(themeProvider.theme.accentColor)
              } else {
                Text(title)
                  .font(.headline)
                  .lineLimit(1)
                  .foregroundColor(themeProvider.theme.toolbarForeground)
              }
              if let mlDoc = card.mlDoc {
                Text(mlDoc.docAuthorName)
                  .font(.body)
                  .lineLimit(nil)
                  .frame(width: MIN_COLUMN_WIDTH)
              }
            } // VStack
            .fixedSize(horizontal: false, vertical: true)
            .foregroundColor(themeProvider.theme.toolbarForeground)
            Spacer()
            if let mlDoc = card.mlDoc {
              Button(action: {
                if player.currentSutta?.sutta_uid != mlDoc.sutta_uid {
                  player.load(mlDoc)
                }
                player.togglePlayback()
              }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                  .font(.title2)
                  .foregroundColor(player
                    .isSynthesizerSpeaking ? .green : themeProvider.theme
                    .toolbarForeground)
                  .frame(minWidth: 44, minHeight: 44)
                  .padding(.leading, 20)
              }
              .buttonStyle(.plain)
              .accessibilityLabel(player.isPlaying ? "a11y.button.pause_audio"
                .localized : "a11y.button.play_audio".localized)
              .foregroundColor(themeProvider.theme.toolbarForeground)
              .contextMenu {
                Button(action: startSynthesis) {
                  Label(
                    "synthesis.background_playback".localized,
                    systemImage: "waveform.circle.fill",
                  )
                }
              }
            } else {
              Image(systemName: "text.page.slash")
                .font(.title2)
                .foregroundColor(themeProvider.theme.errorTextColor)
                .frame(minWidth: 44, minHeight: 44)
            }
          }
          .frame(minWidth: MIN_COLUMN_WIDTH)
        }
      }

    let step2: AnyView = {
      #if os(iOS)
        return AnyView(step1
          .toolbarBackground(
            themeProvider.theme.toolbarBackground,
            for: .navigationBar,
          )
          .toolbarBackground(.visible, for: .navigationBar))
      #else
        return AnyView(step1)
      #endif
    }()

    return step2
  }

  public var body: some View {
    applySuttaModifiers(
      VStack(alignment: .leading, spacing: 0) { // VStack1
        // Title Header
        /*
         SuttaHeaderView(
           card: card,
           player: player,
         )
         .environmentObject(themeProvider)
         .frame(maxWidth: layout?.totalContentWidth ?? .infinity)
         .frame(maxWidth: .infinity, alignment: .center)
         */

        // Segments Content
        if let mlDoc = card.mlDoc {
          GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
              // Capture available width and trigger layout calculation
              let _ = DispatchQueue.main.async {
                if availableWidth != geometry.size.width {
                  availableWidth = geometry.size.width
                  updateLayout()
                }
              }

              if let layout {
                ScrollView(.vertical) {
                  VStack(alignment: .leading, spacing: 8) {
                    ForEach(segments, id: \.scid) { segment in
                      SegmentView(
                        segment: segment,
                        mlDoc: mlDoc,
                        layout: layout,
                        player: player,
                      )
                    }
                  }
                  .frame(maxWidth: layout.totalContentWidth)
                  .padding(.vertical)
                  .background(themeProvider.theme.cardBackground)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                // .scrollContentBackground(.hidden)
                // .background(.red)
                .onAppear {
                  do {
                    cc.ok2(#line, #function, card.suttaReference)
                    if let currentScid = mlDoc.currentScid {
                      // Delay scroll to allow segments to load
                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(reduceMotion ? nil :
                          .easeInOut(duration: 0.8))
                        {
                          // Scroll to two line heights from top
                          scrollProxy.scrollTo(
                            currentScid,
                            anchor: UnitPoint(x: 0.5, y: 0.06),
                          )
                          cc.ok1(#line, "scrollTo:", currentScid)
                        }
                      }
                    }
                  } catch {
                    cc.bad1(#line, #function, card.suttaReference, error)
                  }
                }
                .onChange(of: mlDoc.currentScid) { _, newScid in
                  if let newScid {
                    withAnimation(reduceMotion ? nil :
                      .easeInOut(duration: 0.8))
                    {
                      // Scroll to two line heights from top
                      scrollProxy.scrollTo(
                        newScid,
                        anchor: UnitPoint(x: 0.5, y: 0.06),
                      )
                      cc.ok1(
                        #line,
                        "Scrolled to segment (two line heights from top):",
                        newScid,
                      )
                    }
                  }
                }
              }
            }
          }
        } else {
          VStack(spacing: 12) {
            Image(systemName: "text.page.slash")
              .font(.title)
              .foregroundColor(themeProvider.theme.secondaryTextColor)
            Text("No document loaded")
              .foregroundColor(themeProvider.theme.secondaryTextColor)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
      } // VStack1
      .onAppear {
        if let mlDoc = card.mlDoc {
          segments = mlDoc.segments()
          updateLayout()
          // Initialize currentScid to first segment if nil
          if mlDoc.currentScid == nil, let firstSegment = segments.first {
            mlDoc.currentScid = firstSegment.scid
          }
          cc.ok1(#line, "onAppear \(mlDoc.currentScid ?? "nil")")
        } else {
          cc.ok1(#line, "onAppear no mlDoc")
        }
      }
      .onChange(of: segments) { _, _ in
        updateLayout()
      }
      .onChange(of: Settings.shared.showPali) { _, _ in
        updateLayout()
      }
      .onChange(of: Settings.shared.showDoc) { _, _ in
        updateLayout()
      }
      .onChange(of: Settings.shared.showRef) { _, _ in
        updateLayout()
      }
      .onChange(of: Settings.shared.maxColumnWidth) { _, _ in
        updateLayout()
      }
      .onDisappear {
        // Stop playback when sutta card is dismissed
        // This prevents crashes when a playing sutta card is deleted
        if player.currentSutta?.sutta_uid == card.mlDoc?.sutta_uid {
          player.pause()
          player.currentSutta = nil
          cc.ok1(#line, "Stopped playback on sutta card disappear")
        }

        // Cancel background synthesis if mid-synthesis
        Task {
          await backgroundSession?.cancel()
        }
      }
      .sheet(isPresented: $showSynthesisModal) {
        if let session = backgroundSession {
          SynthesisProgressModal(
            session: session,
            isPresented: $showSynthesisModal,
            themeProvider: themeProvider,
          )
        }
      },
    )
  }

  // MARK: - Private Methods

  private func startSynthesis() {
    guard let suttaRef else {
      cc.bad2(#line, #function, "suttaRef is nil")
      return
    }

    // Create session without callback; modal will poll session.value
    backgroundSession = AudioSynthesisSession(suttaRef)
    showSynthesisModal = true
    cc.ok2(#line, #function, "Starting synthesis for \(suttaRef.toString())")

    // Execute synthesis on background thread
    Task {
      let finalSnapshot = await backgroundSession?.execute()
      cc.ok1(
        #line,
        #function,
        "Synthesis completed: \(finalSnapshot?.state ?? .idle)",
      )
    }
  }
}

// MARK: - SynthesisProgressModal

/// Modal dialog showing background synthesis progress
struct SynthesisProgressModal: View {
  let session: AudioSynthesisSession
  @Binding var isPresented: Bool
  let themeProvider: ThemeProvider
  @State private var currentSnapshot: SessionSnapshot?
  @State private var pollingTask: Task<Void, Never>?
  let cc = ColorConsole(#file, #function, dbg.SuttaCardView.other)

  var body: some View {
    VStack(spacing: 24) {
      // Header with sutta reference
      VStack(spacing: 8) {
        Text("synthesis.title".localized)
          .font(.headline)
          .foregroundColor(themeProvider.theme.textColor)
        if let snapshot = currentSnapshot {
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

          if let snapshot = currentSnapshot, snapshot.totalSteps > 0 {
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

          if let snapshot = currentSnapshot {
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
        if let snapshot = currentSnapshot {
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
      if let snapshot = currentSnapshot {
        let isSynthesizing = if case .synthesizing = snapshot.state { true }
        else { false }
        Button(action: handleButtonTap) {
          Text(isSynthesizing ? "synthesis.cancel".localized : "synthesis.done"
            .localized)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSynthesizing ? Color.red : themeProvider.theme
              .accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
      }

      Spacer()
    }
    .padding(24)
    .background(themeProvider.theme.cardBackground)
    .onAppear {
      startPolling()
    }
    .onDisappear {
      stopPolling()
      // Cancel session if dismissed while synthesizing
      Task {
        await session.cancel()
      }
    }
  }

  private func handleButtonTap() {
    if let snapshot = currentSnapshot {
      let isSynthesizing = if case .synthesizing = snapshot.state { true }
      else { false }
      if isSynthesizing {
        Task {
          await session.cancel()
        }
      } else {
        isPresented = false
      }
    }
  }

  private func startPolling() {
    pollingTask = Task {
      while !Task.isCancelled {
        // Poll session.value for current progress
        let snapshot = await session.value
        currentSnapshot = snapshot
        cc.ok2(
          #line,
          #function,
          "Progress: \(snapshot.currentStep)/\(snapshot.totalSteps)",
        )

        // Sleep for ~0.5s before next poll
        try? await Task.sleep(nanoseconds: 500_000_000)
      }
    }
  }

  private func stopPolling() {
    pollingTask?.cancel()
    pollingTask = nil
  }
}

// MARK: - Preview

#Preview("SuttaCardView") {
  @Previewable @State var mockCard = PreviewCard(
    cardType: .sutta,
    typeId: 1,
    suttaReference: "mn1/en/sujato",
  )

  let manager = PreviewCardManager(
    cards: [mockCard],
    selectedCardId: mockCard.id,
  )

  SuttaCardView(card: $mockCard, cardManager: manager)
    .environmentObject(ThemeProvider())
}
