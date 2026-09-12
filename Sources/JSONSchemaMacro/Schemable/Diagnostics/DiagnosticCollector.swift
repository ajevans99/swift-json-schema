import SwiftDiagnostics

/// Planning accumulates diagnostics without depending on a macro expansion context.
final class DiagnosticCollector {
  private(set) var diagnostics: [Diagnostic] = []

  func diagnose(_ diagnostic: Diagnostic) {
    diagnostics.append(diagnostic)
  }
}
