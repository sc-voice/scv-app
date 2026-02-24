import Testing

extension Tag {
  /// Research tests that verify platform API behavior (not application code)
  /// These tests explore/validate how system APIs work (e.g., AVFoundation)
  /// These tests are slow and should only be run when explicitly needed.
  /// Run with: make test-research
  @Tag static var research: Self
}
