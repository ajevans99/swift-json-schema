import SwiftDiagnostics
import SwiftSyntax

/// Represents the composition keyword that should be emitted in generated schemas.
enum CompositionKeyword {
  case oneOf
  case anyOf

  init(argument: ExprSyntax?) throws {
    guard let argument else {
      self = .oneOf
      return
    }

    switch argument.as(MemberAccessExprSyntax.self)?.declName.baseName.text {
    case "anyOf":
      self = .anyOf
    case "oneOf":
      self = .oneOf
    default:
      throw DiagnosticsError(diagnostics: [
        Diagnostic(
          node: argument,
          message: ConfigurationDiagnostic(
            message: "Schema composition must be an explicit .oneOf or .anyOf"
          )
        )
      ])
    }
  }

  /// Returns the suffix for `JSONComposition` builders (e.g., `OneOf`).
  var jsonCompositionBuilderName: String {
    switch self {
    case .oneOf:
      return "OneOf"
    case .anyOf:
      return "AnyOf"
    }
  }

  /// Returns the member access used when emitting `.orNull(style: ...)`.
  var orNullStyleAccessor: String {
    switch self {
    case .oneOf:
      return ".union"
    case .anyOf:
      return ".unionAnyOf"
    }
  }
}
