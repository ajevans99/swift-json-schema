import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum SchemableError: Error { case unsupportedDeclaration }

extension SchemableError: CustomStringConvertible {
  var description: String {
    switch self {
    case .unsupportedDeclaration: "Macro can only be applied to struct or class"
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
      return [structBuilder]
    } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
      let classBuilder = makeSchema(fromClass: classDecl)
      return [classBuilder]
    }

    throw SchemableError.unsupportedDeclaration
  }
}

func makeSchema(fromClass classDecl: ClassDeclSyntax) -> DeclSyntax {
  let members = classDecl.memberBlock.members
  let attributes = classDecl.attributes
  return makeSchema(members: members, attributes: attributes)
}

func makeSchema(fromStruct structDecl: StructDeclSyntax) -> DeclSyntax {
  let members = structDecl.memberBlock.members
  let attributes = structDecl.attributes
  return makeSchema(members: members, attributes: attributes)
}

func makeSchema(members: MemberBlockItemListSyntax, attributes: AttributeListSyntax) -> DeclSyntax {
  let schemableMembers = members.schemableMembers()

  let statements = schemableMembers.compactMap { $0.jsonSchemaCodeBlock() }

  var codeBlockItem: CodeBlockItemSyntax = "JSONObject { \(CodeBlockItemListSyntax(statements)) }"

  if let annotationArguments = attributes.arguments(for: "SchemaOptions") {
    codeBlockItem.applyArguments(annotationArguments)
  }

  if let objectArguemnts = attributes.arguments(for: "ObjectOptions") {
    codeBlockItem.applyArguments(objectArguemnts)
  } else {
    // Default to adding requirement for non-optional members
    let requiredMemebers = schemableMembers.filter { !$0.isOptional }
    let arrayExpr = ArrayExprSyntax(
      elements: ArrayElementListSyntax(
        requiredMemebers
          .enumerated()
          .map { (index: $0.offset, expression: StringLiteralExprSyntax(content: $0.element.identifier.text)) }
          .map { ArrayElementSyntax(expression: $0.expression, trailingComma: .commaToken(presence: $0.index == requiredMemebers.indices.last ? .missing : .present)) }
      )
    )
    let labeledListExpression = LabeledExprSyntax(
      label: .identifier("required"),
      expression: arrayExpr
    )
    codeBlockItem.applyArguments([labeledListExpression])
  }

  let variableDecl: DeclSyntax = """
    static var schema: JSONSchemaComponent {
      \(codeBlockItem)
    }
    """

  return variableDecl
}

struct SchemableMember {
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
    if let annotationArguments {
      codeBlock.applyArguments(annotationArguments)
    }

    if let typeSpecificArguments {
      codeBlock.applyArguments(typeSpecificArguments)
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

extension PatternBindingListSyntax.Element {
  // Modified implementation from https://github.com/swiftlang/swift-syntax/blob/248dcef04d9e03b7fc47905a81fc84c6f6c23837/Examples/Sources/MacroExamples/Implementation/MemberAttribute/WrapStoredPropertiesMacro.swift#L65
  var isStoredProperty: Bool {
    switch accessorBlock?.accessors {
    case .accessors(let accessors):
      for accessor in accessors {
        switch accessor.accessorSpecifier.tokenKind {
        case .keyword(.willSet), .keyword(.didSet):
          // Observers can occur on a stored property.
          break
        default:
          // Other accessors make it a computed property.
          return false
        }
      }
      return true
    case .getter:
      return false
    case nil:
      return true
    }
  }
}

extension MemberBlockItemListSyntax {
  func schemableMembers() -> [SchemableMember] {
    self
      .compactMap { $0.decl.as(VariableDeclSyntax.self) }
      .flatMap { variableDecl in variableDecl.bindings.map { (variableDecl, $0) } }
      .filter { $0.1.isStoredProperty }
      .compactMap { (variableDecl, patternBinding) -> SchemableMember? in
        guard let identifier = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier
        else { return nil }
        guard let type = patternBinding.typeAnnotation?.type else { return nil }

        return SchemableMember(identifier: identifier, type: type, attributes: variableDecl.attributes)
      }
  }
}

extension CodeBlockItemSyntax {
  mutating func applyArguments(_ arguments: LabeledExprListSyntax) {
    for argument in arguments {
      if let label = argument.label {
        self = """
            \(self)
            .\(label.trimmed)(\(argument.expression))
            """
      }
    }
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
