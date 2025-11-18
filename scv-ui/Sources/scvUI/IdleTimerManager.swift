//
//  IdleTimerManager.swift
//  scv-ui
//
//  Created by Claude on 2025-11-18.
//

#if os(iOS)
  import UIKit

  /// Manages idle timer state on iOS to prevent screen sleep during playback
  public enum IdleTimerManager {
    /// Disable idle timer (prevent screen sleep)
    public static func disableIdleTimer() {
      UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Enable idle timer (allow screen sleep)
    public static func enableIdleTimer() {
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }
#else
  /// macOS does not need idle timer management
  public enum IdleTimerManager {
    /// No-op on macOS
    public static func disableIdleTimer() {}

    /// No-op on macOS
    public static func enableIdleTimer() {}
  }
#endif
