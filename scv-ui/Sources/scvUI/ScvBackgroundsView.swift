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

  @ViewBuilder
  public var view: some View {
    Group {
      switch self {
      case .village:
        Image("seurat-background", bundle: .scvUI)
          .resizable()
          .aspectRatio(contentMode: .fill)
      case .sangha:
        Image("sangha-background", bundle: .scvUI)
          .resizable()
          .aspectRatio(contentMode: .fill)
      case .sangha_dark:
        Image("sangha-dark-background", bundle: .scvUI)
          .resizable()
          .aspectRatio(contentMode: .fill)
      case .wilderness:
        Image("wilderness-background", bundle: .scvUI)
          .resizable()
          .aspectRatio(contentMode: .fill)
      case .space:
        Image("space-background", bundle: .scvUI)
          .resizable()
          .aspectRatio(contentMode: .fill)
      case .nothingness:
        Image("nothingness-background", bundle: .scvUI)
          .resizable()
          .aspectRatio(contentMode: .fill)
      case .palm_leaf:
        GeometryReader { geometry in
          Image("palm-leaf", bundle: .scvUI)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(
              width: geometry.size.width * 1.2,
              height: geometry.size.height * 1.2,
            )
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .offset(y: -geometry.size.height * 0.1)
        }
      }
    }
    .opacity(0.5)
  }
}

public struct ScvBackgroundsView: View {
  let background: ScvBackground
  @Environment(\.colorScheme) var colorScheme

  public init(_ background: ScvBackground = .nothingness) {
    self.background = background
  }

  public var body: some View {
    background.view
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      // .overlay(
      // Group {
      // if colorScheme == .light && background == .palm_leaf {
      // Color.white.opacity(0.4)
      // }
      // }
      // )
      .ignoresSafeArea()
  }
}

#Preview {
  ScvBackgroundsView()
}
