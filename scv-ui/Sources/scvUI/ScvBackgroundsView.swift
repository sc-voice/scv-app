//
//  ScvBackgroundsView.swift
//  scv-ui
//
//  Created by Claude on 2025-12-06.
//

import SwiftUI

public enum ScvBackground {
  case village
  case sangha
  case sangha_dark
  case wilderness
  case space
  case nothingness
  case palm_leaf

  public var source: URL {
    switch self {
    case .village:
      URL(
        string: "https://en.wikipedia.org/wiki/File:A_Sunday_on_La_Grande_Jatte,_Georges_Seurat,_1884.jpg",
      )!
    case .sangha:
      URL(
        string: "https://commons.wikimedia.org/wiki/File:Phutthamonthon_Buddha.JPG",
      )!
    case .sangha_dark:
      URL(
        string: "https://en.wikipedia.org/wiki/Sangha#/media/File:Bodleian_MS._Burm._a._12_Life_of_the_Buddha_15-18.jpg",
      )!
    case .wilderness:
      URL(
        string: "https://www.rawpixel.com/image/3284999/free-photo-image-summer-forest-way",
      )!
    case .space:
      URL(string: "https://www.rawpixel.com/image/3864335")!
    case .nothingness:
      URL(
        string: "https://www.publicdomainpictures.net/en/view-image.php?image=20131&picture=white-sands-5",
      )!
    case .palm_leaf:
      URL(
        string: "https://wellcomecollection.org/collections",
      )!
    }
  }

  private func backgroundImage() -> Image {
    switch self {
    case .village:
      Image("seurat-background", bundle: .scvUI)
    case .sangha:
      Image("sangha-background", bundle: .scvUI)
    case .sangha_dark:
      Image("sangha-dark-background", bundle: .scvUI)
    case .wilderness:
      Image("wilderness-background", bundle: .scvUI)
    case .space:
      Image("space-background", bundle: .scvUI)
    case .nothingness:
      Image("nothingness-background", bundle: .scvUI)
    case .palm_leaf:
      Image("palm-leaf", bundle: .scvUI)
    }
  }

  @ViewBuilder
  public var view: some View {
    backgroundImage()
      .resizable()
      .aspectRatio(contentMode: .fill)
  }
}

public struct ScvBackgroundsView: View {
  let background: ScvBackground
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.accessibilityReduceMotion) var reduceMotion
  @State private var opacity: Double = 1.0

  public init(_ background: ScvBackground = .nothingness) {
    self.background = background
  }

  public var body: some View {
    background.view
      .background(Color.white)
      .opacity(opacity)
      .onAppear {
        withAnimation(reduceMotion ? nil : .linear(duration: 30)) {
          opacity = 0.3
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .ignoresSafeArea()
  }
}

#Preview {
  ScvBackgroundsView()
}
