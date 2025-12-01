import SwiftSyntax

/// Represents the composition keyword that should be emitted in generated schemas.
enum CompositionKeyword {
  case oneOf
  case anyOf

  init(argument: ExprSyntax?) {
    guard let argument else {
      self = .oneOf
      return
    }

    if let memberAccess = argument.as(MemberAccessExprSyntax.self) {
      self = CompositionKeyword(baseName: memberAccess.declName.baseName.text)
    } else if let declReference = argument.as(DeclReferenceExprSyntax.self) {
      self = CompositionKeyword(baseName: declReference.baseName.text)
    } else {
      self = .oneOf
    }
  }

  private init(baseName: String) {
    switch baseName.lowercased() {
    case "anyof":
      self = .anyOf
    default:
      self = .oneOf
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
