//
//  SplashScreenView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-04.
//

import scvCore
import SwiftUI

public struct SplashScreenView: View {
  let cc = ColorConsole(#file, #function, dbg.AppRootView.other)
  let appIcon: Image?
  @EnvironmentObject var themeProvider: ThemeProvider

  public init(appIcon: Image? = nil) {
    self.appIcon = appIcon
  }

  @State private var backgroundOpacity: Double = 1.0

  public var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .top) {
        ScvProgressView(appIcon: appIcon)
          .background(ScvBackgroundsView(.village)
            .opacity(backgroundOpacity))

        VStack(spacing: 4) {
          Text("scVoice")
            .font(.headline)
            .fontWeight(.semibold)
            .background(themeProvider.theme.toolbarBackground)
            .padding(12)
          Text("Build \(buildVersion)")
            .font(.caption2)
            .background(themeProvider.theme.toolbarBackground)
            .padding(12)
        }
        .background(themeProvider.theme.toolbarBackground)
        .cornerRadius(6)
        .frame(width: 350, height: geometry.size.height / 3, alignment: .bottom)
        .zIndex(100)
      }
    }
    .onAppear {
      cc.ok1(#line, #function, "onAppear")
      withAnimation(.linear(duration: 10)) {
        backgroundOpacity = 0.3
      }
    }
  }
}

#Preview {
  SplashScreenView()
}
