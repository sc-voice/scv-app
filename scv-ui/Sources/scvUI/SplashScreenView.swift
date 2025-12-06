//
//  SplashScreenView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-04.
//

import SwiftUI

public struct SplashScreenView: View {
  let cc = ColorConsole(#file, #function, dbg.AppRootView.other)
  let appIcon: Image?

  public init(appIcon: Image? = nil) {
    self.appIcon = appIcon
  }

  public var body: some View {
    ZStack {
      VStack(spacing: 20) {
        Spacer()

        // App logo or name
        if let appIcon {
          appIcon
            .resizable()
            .scaledToFit()
            .opacity(0.8)
            .frame(width: 80, height: 80)
            .onAppear {
              // Gave up trying to animate this
              cc.ok1(#line, #function, "onAppear")
            }
        } else {
          Text("SC Voice")
            .font(.title)
            .fontWeight(.bold)
        }

        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      ProgressView()
        .scaleEffect(2.1, anchor: .center)
    }
  }
}

#Preview {
  SplashScreenView()
}
