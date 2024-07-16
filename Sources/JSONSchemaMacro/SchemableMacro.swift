import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum SchemableError: Error { case unsupportedDeclaration }

extension SchemableError: CustomStringConvertible {
  var description: String {
    switch self {
    case .unsupportedDeclaration: "Macro can only be applied to struct"
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
  let members = structDecl.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
    .flatMap { variableDecl in variableDecl.bindings.map { (variableDecl, $0) } }
    .compactMap { (variableDecl, patternBinding) -> Member? in
      guard let identifier = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier
      else { return nil }
      guard let type = patternBinding.typeAnnotation?.type else { return nil }

      return Member(identifier: identifier, type: type, attributes: variableDecl.attributes)
    }

  let statements = members.compactMap { $0.jsonSchemaCodeBlock() }

  let requiredMemebers = members.filter { !$0.isOptional }

  let variableDecl: DeclSyntax = """
    static var schema: JSONSchemaComponent {
      JSONObject { \(CodeBlockItemListSyntax(statements)) }
      .required([\(raw: requiredMemebers.map { "\"\($0.identifier.text)\"" }.joined(separator: ","))])
    }
    """

  return variableDecl
}

struct Member {
  let identifier: TokenSyntax
  let type: TypeSyntax
  let attributes: AttributeListSyntax

  var annotationArguments: LabeledExprListSyntax? {
    attributes.arguments(for: "SchemaOptions")
  }
  
  var typeSpecificArguments: LabeledExprListSyntax? {
    let typeSpecificMacroNames = ["NumberOptions", "ArrayOptions", "ObjectOptions", "StringOptions"]
    for macroName in typeSpecificMacroNames {
      if let arguments = attributes.arguments(for: macroName) {
        return arguments
      }
    }
    return nil
  }

  var isOptional: Bool {
    // Check for explicit optional like `let snow: Optional<Double>`
    if let identifierType = type.as(IdentifierTypeSyntax.self) {
      return identifierType.name.text == "Optional"
    }

    // Check for postfix optional like `let rain: Double?`
    return type.is(OptionalTypeSyntax.self)
  }

  func applyArguments(to codeBlock: inout CodeBlockItemSyntax) {
    func applyArguments(_ arguments: LabeledExprListSyntax) {
      for argument in arguments {
        if let label = argument.label {
          codeBlock = """
            \(codeBlock)
              .\(label.trimmed)(\(argument.expression))
            """
        }
      }
    }

    if let annotationArguments {
      applyArguments(annotationArguments)
    }

    if let typeSpecificArguments {
      applyArguments(typeSpecificArguments)
    }
  }

  func jsonSchemaCodeBlock() -> CodeBlockItemSyntax? {
    guard var typeCodeBlock = type.jsonSchemaCodeBlock() else { return nil }

    applyArguments(to: &typeCodeBlock)

    return """
      JSONProperty(key: "\(raw: identifier.text)") { \(typeCodeBlock) }
      """
  }
}

extension AttributeListSyntax {
  func arguments(for attributeName: String) -> LabeledExprListSyntax? {
    self.compactMap { $0.as(AttributeSyntax.self) }
      .first {
        guard let attributeIdentifier = $0.attributeName.as(IdentifierTypeSyntax.self) else {
          return false
        }
        return attributeIdentifier.name.text == attributeName
      }?
      .arguments?
      .as(LabeledExprListSyntax.self)
  }
}

extension TypeSyntax {
  func jsonSchemaCodeBlock() -> CodeBlockItemSyntax? {
    switch self.as(TypeSyntaxEnum.self) {
    case .arrayType(let arrayType):
      guard let type = arrayType.element.jsonSchemaCodeBlock() else { return nil }
      return """
        JSONArray()
          .items {
            \(type)
          }
        """
    case .dictionaryType(let dictionaryType):
      guard let keyType = dictionaryType.key.as(IdentifierTypeSyntax.self),
        keyType.name.text == "String"
      else {
        // TODO: Add warning
        return nil
      }
      guard let type = dictionaryType.value.jsonSchemaCodeBlock() else { return nil }
      return """
        JSONObject()
          .additionalProperties {
            \(type)
          }
        """
    case .identifierType(let identifierType):
      guard let type = jsonType(from: identifierType.name.text) else {
        return "\(raw: identifierType.name.text).schema"
      }
      return "\(type)()"
    case .implicitlyUnwrappedOptionalType(let implicitlyUnwrappedOptionalType):
      return implicitlyUnwrappedOptionalType.wrappedType.jsonSchemaCodeBlock()
    case .optionalType(let optionalType): return optionalType.wrappedType.jsonSchemaCodeBlock()
    case .someOrAnyType(let someOrAnyType): return someOrAnyType.constraint.jsonSchemaCodeBlock()
    case .attributedType, .classRestrictionType, .compositionType, .functionType, .memberType,
      .metatypeType, .missingType, .namedOpaqueReturnType, .packElementType, .packExpansionType,
      .suppressedType, .tupleType:
      return nil
    }
  }

  func jsonType(from text: String) -> DeclReferenceExprSyntax? {
    let identifier: String? =
      switch text {
      case "Double": "JSONNumber"
      case "Bool": "JSONBoolean"
      case "Int": "JSONInteger"
      case "String": "JSONString"
      default: nil
      }
    guard let identifier else { return nil }
    return .init(baseName: .identifier(identifier))
  }
}
