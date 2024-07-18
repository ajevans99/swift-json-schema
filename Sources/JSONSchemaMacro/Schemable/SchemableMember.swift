import SwiftSyntax

struct SchemableMember {
  let identifier: TokenSyntax
  let type: TypeSyntax
  let attributes: AttributeListSyntax
  let defaultValue: ExprSyntax?

  var annotationArguments: LabeledExprListSyntax? { attributes.arguments(for: "SchemaOptions") }

  var typeSpecificArguments: LabeledExprListSyntax? {
    let typeSpecificMacroNames = [
      "NumberOptions", "ArrayOptions", "ObjectOptions", "StringOptions",
    ]
    for macroName in typeSpecificMacroNames {
      if let arguments = attributes.arguments(for: macroName) { return arguments }
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

  private init(identifier: TokenSyntax, type: TypeSyntax, attributes: AttributeListSyntax, defaultValue: ExprSyntax? = nil) {
    self.identifier = identifier
    self.type = type
    self.attributes = attributes
    self.defaultValue = defaultValue
  }

  init?(variableDecl: VariableDeclSyntax, patternBinding: PatternBindingSyntax) {
    guard let identifier = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier
    else { return nil }
    guard let type = patternBinding.typeAnnotation?.type else { return nil }

    self.init(
      identifier: identifier,
      type: type,
      attributes: variableDecl.attributes,
      defaultValue: patternBinding.initializer?.value
    )
  }

  func applyArguments(to codeBlock: inout CodeBlockItemSyntax) {
    if let annotationArguments { codeBlock.applyArguments(annotationArguments) }

    if let typeSpecificArguments { codeBlock.applyArguments(typeSpecificArguments) }
  }

  enum TypeInformation {
    case primative(SupportedPrimative, schema: CodeBlockItemSyntax)
    case schemable(String, schema: CodeBlockItemSyntax)
    case notSupported

    var codeBlock: CodeBlockItemSyntax? {
      switch self {
      case .primative(_, let schema):
        schema
      case .schemable(_, let schema):
        schema
      case .notSupported:
        nil
      }
    }
  }

  func generateSchema() -> CodeBlockItemSyntax? {
    var codeBlock: CodeBlockItemSyntax
    switch typeInformation(from: type) {
    case .primative(_, let code):
      codeBlock = code
      // Only use default value on primatives that can be `ExpressibleBy*Literal` to transform
      // from Swift type to JSONValue (required by .default())
      // In the future, JSONValue types should also be allowed to apply default value
      if let defaultValue {
        codeBlock = """
        \(codeBlock)
        .default(\(defaultValue))
        """
      }
    case .schemable(_, let code):
      codeBlock = code
    case .notSupported: return nil
    }

    applyArguments(to: &codeBlock)

    return """
      JSONProperty(key: "\(raw: identifier.text)") { \(codeBlock) }
      """
  }

  private func typeInformation(from typeSyntax: TypeSyntax) -> TypeInformation {
    switch typeSyntax.as(TypeSyntaxEnum.self) {
    case .arrayType(let arrayType):
      guard let codeBlock = typeInformation(from: arrayType.element).codeBlock else { return .notSupported }
      return .primative(
        .array,
        schema: """
          JSONArray()
          .items {
            \(codeBlock)
          }
          """
        )
    case .dictionaryType(let dictionaryType):
      guard let keyType = dictionaryType.key.as(IdentifierTypeSyntax.self),
            keyType.name.text == "String"
      else {
        return .notSupported
      }
      guard let codeBlock = typeInformation(from: dictionaryType.value).codeBlock else { return .notSupported }
      return .primative(
        .dictionary,
        schema: """
          JSONObject()
          .additionalProperties {
            \(codeBlock)
          }
          """
        )
    case .identifierType(let identifierType):
      if let generic = identifierType.genericArgumentClause {
        guard identifierType.name.text != "Array" else {
          let arrayType = ArrayTypeSyntax(element: generic.arguments.first!.argument)
          return typeInformation(from: TypeSyntax(arrayType))
        }

        guard identifierType.name.text != "Dictionary" else {
          let test = Array(generic.arguments.prefix(2))
          let dictionaryType = DictionaryTypeSyntax(key: test[0].argument, value: test[1].argument)
          return typeInformation(from: TypeSyntax(dictionaryType))
        }
      }

      guard let primative = SupportedPrimative(rawValue: identifierType.name.text) else {
        return .schemable(identifierType.name.text, schema: "\(raw: identifierType.name.text).schema")
      }

      return .primative(primative, schema: "\(raw: primative.schema)()")
    case .implicitlyUnwrappedOptionalType(let implicitlyUnwrappedOptionalType):
      return typeInformation(from: implicitlyUnwrappedOptionalType.wrappedType)
    case .optionalType(let optionalType): return typeInformation(from: optionalType.wrappedType)
    case .someOrAnyType(let someOrAnyType): return typeInformation(from: someOrAnyType.constraint)
    case .attributedType, .classRestrictionType, .compositionType, .functionType, .memberType,
        .metatypeType, .missingType, .namedOpaqueReturnType, .packElementType, .packExpansionType,
        .suppressedType, .tupleType:
      return .notSupported
    }
  }
}
