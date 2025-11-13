// TODO: Remove this once Swift Package Manager fixes cross-package macro plugin discovery
// See: https://github.com/apple/swift-package-manager/issues/6950
#if CROSS_PACKAGE_MACROS

  /// Variadic macro that expands to cc.ok1() with file, function, and line
  /// information
  ///
  /// Usage:
  /// ```
  /// CCOK1(1, "message1", "message2")
  /// ```
  ///
  /// Expands to:
  /// ```
  /// cc.ok1(path: #file, method: #function, line: #line, "message1",
  /// "message2")
  /// ```
  @freestanding(expression)
  public macro CCOK1(level: Int, _ messages: Any...) = #externalMacro(
    module: "scvMacrosPlugin",
    type: "CCOK1Macro",
  )

#endif
