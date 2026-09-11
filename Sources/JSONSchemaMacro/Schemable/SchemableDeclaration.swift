import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder

struct MacroConfiguration {
  let keyStrategy: ExprSyntax?
  let optionalNulls: Bool
  let optionalNullUnion: CompositionKeyword
  let enumComposition: CompositionKeyword

  init(attribute: AttributeSyntax) throws {
    let arguments = attribute.arguments?.as(LabeledExprListSyntax.self)
    func argument(_ name: String) -> ExprSyntax? {
      arguments?.first { $0.label?.text == name }?.expression
    }
    keyStrategy = argument("keyStrategy")
    if let value = argument("optionalNulls") {
      guard let literal = value.as(BooleanLiteralExprSyntax.self) else {
        throw DiagnosticsError(diagnostics: [
          Diagnostic(
            node: value,
            message: ConfigurationDiagnostic(message: "optionalNulls must be a boolean literal")
          )
        ])
      }
      optionalNulls = literal.literal.tokenKind == .keyword(.true)
    } else {
      optionalNulls = true
    }
    optionalNullUnion = try CompositionKeyword(argument: argument("optionalNullUnion"))
    enumComposition = try CompositionKeyword(argument: argument("enumComposition"))
  }
}

struct ConfigurationDiagnostic: DiagnosticMessage {
  let message: String
  var diagnosticID: MessageID {
    MessageID(domain: "JSONSchemaMacro", id: "invalidConfiguration")
  }
  var severity: DiagnosticSeverity { .error }
}

struct SchemableDeclaration {
  enum Kind {
    case structure
    case classType
    case enumeration
  }

  let kind: Kind
  let name: TokenSyntax
  let accessModifier: DeclModifierSyntax?
  let options: ParsedOptions
  let properties: [SchemableMember]
  let cases: [SchemableEnumCase]
  let initializers: [InitializerDeclSyntax]
  let codingKeys: [String: String]?
  let diagnostics: [Diagnostic]

  init(_ declaration: some DeclGroupSyntax, lexicalContext: [Syntax]) throws {
    if let declaration = declaration.as(StructDeclSyntax.self) {
      kind = .structure
      name = declaration.name.trimmed
    } else if let declaration = declaration.as(ClassDeclSyntax.self) {
      kind = .classType
      name = declaration.name.trimmed
    } else if let declaration = declaration.as(EnumDeclSyntax.self) {
      kind = .enumeration
      name = declaration.name.trimmed
    } else {
      throw SchemableError.unsupportedDeclaration
    }

    accessModifier = Self.accessModifier(for: declaration, lexicalContext: lexicalContext)
    options = ParsedOptions(attributes: declaration.attributes)
    let members = declaration.memberBlock.members
    initializers = members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }
    codingKeys = members.extractCodingKeys()
    let isStringBacked =
      declaration.inheritanceClause?.inheritedTypes
      .contains {
        ["String", "Swift.String"].contains($0.type.trimmedDescription)
      } ?? false
    cases = members.schemableEnumCases(isStringBacked: isStringBacked)

    var properties: [SchemableMember] = []
    var diagnostics: [Diagnostic] = []
    if kind != .enumeration {
      for item in members {
        guard let variable = item.decl.as(VariableDeclSyntax.self), !variable.isStatic else {
          continue
        }
        for binding in variable.bindings where binding.isStoredProperty {
          if let member = SchemableMember(variableDecl: variable, patternBinding: binding) {
            properties.append(member)
          } else if !variable.attributes.contains(where: {
            $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "ExcludeFromSchema"
          }) {
            diagnostics.append(
              Diagnostic(
                node: binding.pattern,
                message: UnsupportedTypeDiagnostic.missingTypeAnnotation
              )
            )
          }
        }
      }
    }
    self.properties = properties
    self.diagnostics = diagnostics
  }

  private static func accessModifier(
    for declaration: some DeclGroupSyntax,
    lexicalContext: [Syntax]
  ) -> DeclModifierSyntax? {
    let accessLevels = ["open", "public", "internal", "package", "fileprivate", "private"]
    let explicit = declaration.modifiers.first { accessLevels.contains($0.name.text) }
    let inherited = lexicalContext.lazy.compactMap { $0.as(ExtensionDeclSyntax.self) }
      .compactMap { declaration in
        declaration.modifiers.first { ["public", "package", "internal"].contains($0.name.text) }
      }
      .first
    guard let modifier = explicit ?? inherited else { return nil }
    let witnessAccess: String
    switch modifier.name.text {
    case "open": witnessAccess = "public"
    case "private": witnessAccess = "fileprivate"
    default: witnessAccess = modifier.name.text
    }
    return DeclModifierSyntax(
      name: .identifier(witnessAccess),
      trailingTrivia: .space
    )
  }
}
