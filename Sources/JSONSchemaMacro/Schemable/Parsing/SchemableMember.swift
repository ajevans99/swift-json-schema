import SwiftDiagnostics
import SwiftSyntax

struct SchemableMember {
  let identifier: TokenSyntax
  let type: TypeSyntax
  let options: ParsedOptions
  let defaultValue: ExprSyntax?
  let docString: String?
  let isVariable: Bool
  let isExcluded: Bool

  init?(variableDecl: VariableDeclSyntax, patternBinding: PatternBindingSyntax) {
    guard let identifier = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
      let type = patternBinding.typeAnnotation?.type
    else { return nil }
    self.identifier = identifier
    self.type = type
    options = ParsedOptions(attributes: variableDecl.attributes)
    defaultValue = patternBinding.initializer?.value
    docString = variableDecl.docString
    isVariable = variableDecl.bindingSpecifier.tokenKind == .keyword(.var)
    isExcluded = variableDecl.attributes.contains {
      $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "ExcludeFromSchema"
    }
  }
}

enum UnsupportedTypeDiagnostic: DiagnosticMessage {
  case propertyTypeNotSupported(propertyName: String, typeName: String)
  case enumPayloadNotSupported(caseName: String, typeName: String)
  case recursiveEnumPayload(caseName: String)
  case duplicateEnumPayloadKey(caseName: String, key: String)
  case missingTypeAnnotation

  var message: String {
    switch self {
    case .propertyTypeNotSupported(let propertyName, let typeName):
      return """
        Property '\(propertyName)' has type '\(typeName)' which is not supported by the @Schemable macro. \
        This property will be excluded from the generated schema, which may cause the schema to not match \
        the memberwise initializer.
        """
    case .enumPayloadNotSupported(let caseName, let typeName):
      return
        "Enum case '\(caseName)' has unsupported associated value type '\(typeName)'; the case cannot be included in the generated schema"
    case .recursiveEnumPayload(let caseName):
      return
        "Recursive enum payloads are not supported by @Schemable (case '\(caseName)'); provide a manual schema"
    case .duplicateEnumPayloadKey(let caseName, let key):
      return
        "Enum case '\(caseName)' has duplicate JSON key '\(key)'; use distinct associated value labels"
    case .missingTypeAnnotation:
      return "Stored properties included by @Schemable must have an explicit type annotation"
    }
  }

  var diagnosticID: MessageID {
    switch self {
    case .propertyTypeNotSupported:
      return MessageID(domain: "JSONSchemaMacro", id: "unsupportedType")
    case .enumPayloadNotSupported:
      return MessageID(domain: "JSONSchemaMacro", id: "unsupportedEnumPayload")
    case .recursiveEnumPayload:
      return MessageID(domain: "JSONSchemaMacro", id: "recursiveEnumPayload")
    case .duplicateEnumPayloadKey:
      return MessageID(domain: "JSONSchemaMacro", id: "duplicateEnumPayloadKey")
    case .missingTypeAnnotation:
      return MessageID(domain: "JSONSchemaMacro", id: "missingTypeAnnotation")
    }
  }

  var severity: DiagnosticSeverity {
    switch self {
    case .propertyTypeNotSupported: .warning
    case .enumPayloadNotSupported, .recursiveEnumPayload, .duplicateEnumPayloadKey,
      .missingTypeAnnotation:
      .error
    }
  }
}
