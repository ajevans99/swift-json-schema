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

  private init(
    identifier: TokenSyntax,
    type: TypeSyntax,
    attributes: AttributeListSyntax,
    defaultValue: ExprSyntax? = nil
  ) {
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

  func generateSchema() -> CodeBlockItemSyntax? {
    var codeBlock: CodeBlockItemSyntax
    switch type.typeInformation() {
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
    case .schemable(_, let code): codeBlock = code
    case .notSupported: return nil
    }

    // Apply schema options if present
    if let annotationArguments = annotationArguments {
      codeBlock = SchemaOptionsGenerator.apply(annotationArguments, to: codeBlock, for: "SchemaOptions")
    }

    // Apply type-specific options if present
    if let typeSpecificArguments = typeSpecificArguments {
      codeBlock = SchemaOptionsGenerator.apply(typeSpecificArguments, to: codeBlock, for: type.description)
    }

    var block: CodeBlockItemSyntax = """
      JSONProperty(key: "\(raw: identifier.text)") { \(codeBlock) }
      """

    if !type.isOptional {
      block = """
        \(block)
        .required()
        """
    }

    return block
  }
}
