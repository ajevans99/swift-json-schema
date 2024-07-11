import SwiftSyntax
import SwiftSyntaxMacros

enum SchemableError: Error {
  case unsupportedDeclaration
}

extension SchemableError: CustomStringConvertible {
  var description: String {
    switch self {
    case .unsupportedDeclaration:
      "Macro can only be applied to struct"
    }
  }
}

public struct SchemableMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let schemableExtension = try ExtensionDeclSyntax("extension \(type.trimmed): Schemable {}")

    return [schemableExtension]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    if let structDecl = declaration.as(StructDeclSyntax.self) {
      let structBuilder = makeSchema(fromStruct: structDecl)
      return [DeclSyntax(structBuilder)]
    }

    throw SchemableError.unsupportedDeclaration
  }
}

func makeSchema(fromStruct structDecl: StructDeclSyntax) -> DeclSyntax {
  let members = structDecl.memberBlock.members
    .compactMap { $0.decl.as(VariableDeclSyntax.self) }
    .flatMap { $0.bindings }
    .compactMap { patternBinding -> Member? in
      guard let identifier = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier else { return nil }
      guard let type = patternBinding.typeAnnotation?.type else { return nil }

      return Member(identifier: identifier, type: type)
    }

  let statements = members
    .compactMap { member -> CodeBlockItemSyntax? in
      guard let jsonType = member.jsonType else {
        if let text = member.type.as(IdentifierTypeSyntax.self) {
          return "JSONProperty(key: \"\(member.identifier)\") { \(raw: text.name.text).schema }"
        }

        return nil
      }
      return "JSONProperty(key: \"\(member.identifier)\") { JSON\(raw: jsonType)() }"
    }

  let variableDecl = VariableDeclSyntax(
    leadingTrivia: .newline,
    modifiers: [DeclModifierSyntax(name: .keyword(.static))],
    bindingSpecifier: .keyword(.let),
    bindings: [
      PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: "schema"),
        typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("JSONSchemaRepresentable"))),
        initializer: InitializerClauseSyntax(
          value: FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: "JSONObject"),
            arguments: [],
            trailingClosure: ClosureExprSyntax(
              statements: CodeBlockItemListSyntax(statements)
            )
          )
        )
      )
    ]
  )

  return DeclSyntax(variableDecl)
}

struct Member {
  let identifier: TokenSyntax
  let type: TypeSyntax

  var jsonType: String? {
    // TODO: Arrays and dictionaries
//    if let type = type.as(ArrayTypeSyntax.self) {
//      return type.element
//    }

    guard let type = type.as(IdentifierTypeSyntax.self) else {
      return nil
    }

    switch type.name.text {
    case "Double":
      return "Number"
    case "Bool":
      return "Boolean"
    case "Int":
      return "Integer"
    case "String":
      return "String"
    default:
      return nil
    }
  }
}
