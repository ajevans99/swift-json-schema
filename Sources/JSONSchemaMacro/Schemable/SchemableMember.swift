import SwiftSyntax

struct SchemableMember {
  let identifier: TokenSyntax
  let type: TypeSyntax
  let attributes: AttributeListSyntax
  let defaultValue: ExprSyntax?
  let docString: String?

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

  private var schemaCustomKey: ExprSyntax? {
    guard let annotationArguments else { return nil }
    for argument in annotationArguments {
      guard let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
        let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self),
        memberAccess.declName.baseName.text == "key"
      else { continue }
      return functionCall.arguments.first?.expression
    }
    return nil
  }

  private var customSchemaExpression: ExprSyntax? {
    guard let annotationArguments else { return nil }
    for argument in annotationArguments {
      guard let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
        let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self),
        memberAccess.declName.baseName.text == "customSchema"
      else { continue }
      return functionCall.arguments.first?.expression
    }
    return nil
  }

  private init(
    identifier: TokenSyntax,
    type: TypeSyntax,
    attributes: AttributeListSyntax,
    defaultValue: ExprSyntax? = nil,
    docString: String? = nil
  ) {
    self.identifier = identifier
    self.type = type
    self.attributes = attributes
    self.defaultValue = defaultValue
    self.docString = docString
  }

  init?(variableDecl: VariableDeclSyntax, patternBinding: PatternBindingSyntax) {
    guard let identifier = patternBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier
    else { return nil }
    guard let type = patternBinding.typeAnnotation?.type else { return nil }

    self.init(
      identifier: identifier,
      type: type,
      attributes: variableDecl.attributes,
      defaultValue: patternBinding.initializer?.value,
      docString: variableDecl.docString
    )
  }

  func generateSchema(keyStrategy: ExprSyntax?, typeName: String) -> CodeBlockItemSyntax? {
    var codeBlock: CodeBlockItemSyntax
    switch type.typeInformation() {
    case .primitive(_, let code):
      codeBlock = code
      // Only use default value on primitives that can be `ExpressibleBy*Literal` to transform
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

    let options: LabeledExprListSyntax? = annotationArguments.flatMap { args in
      let filtered = args.filter { argument in
        guard let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
          let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
        else { return true }

        return memberAccess.declName.baseName.text != "key"
      }
      return filtered.isEmpty ? nil : LabeledExprListSyntax(filtered)
    }

    // Apply schema options if present
    if let options, !options.isEmpty {
      codeBlock = SchemaOptionsGenerator.apply(
        options,
        to: codeBlock,
        for: "SchemaOptions"
      )
    }

    // Apply type-specific options if present
    if let typeSpecificArguments = typeSpecificArguments {
      codeBlock = SchemaOptionsGenerator.apply(
        typeSpecificArguments,
        to: codeBlock,
        for: type.description
      )
    }

    // Apply docstring if present and no description was set via SchemaOptions
    if let docString, !hasDescriptionInOptions {
      codeBlock = """
        \(codeBlock)
        .description(#\"\"\"
        \(raw: docString)
        \"\"\"#)
        """
    }

    let keyExpr = keyExpression(
      usingKeyStrategy: keyStrategy != nil,
      typeName: typeName,
      useSelfReference: false
    )

    var block: CodeBlockItemSyntax = """
      JSONProperty(key: \(keyExpr)) { \(codeBlock) }
      """

    if !type.isOptional {
      block = """
        \(block)
        .required()
        """
    }

    return block
  }

  func generateEncodingStatements(
    hasKeyStrategy: Bool,
    typeName: TokenSyntax,
    keyIndex: Int
  ) -> [CodeBlockItemSyntax]? {
    let keyExpr = keyExpression(
      usingKeyStrategy: hasKeyStrategy,
      typeName: typeName.text,
      useSelfReference: true
    )
    let keyVariableName = "key\(keyIndex)"
    let context = "\(typeName.text).\(identifier.text)"

    let propertyExpr = ExprSyntax(
      MemberAccessExprSyntax(
        base: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("value"))),
        period: .periodToken(),
        declName: DeclReferenceExprSyntax(baseName: identifier)
      )
    )

    if let wrapped = type.unwrappedOptionalType() {
      let optionalName = "value\(keyIndex)"
      guard
        let encodedExpr = wrapped.encodeExpression(
          valueExpr: identifierExpr(optionalName),
          customSchema: customSchemaExpression,
          context: context
        )
      else { return nil }

      return [
        """
        if let \(raw: optionalName) = \(propertyExpr) {
          let \(raw: keyVariableName) = \(keyExpr)
          object[\(raw: keyVariableName)] = \(encodedExpr)
        }
        """
      ]
    }

    guard
      let encodedExpr = type.encodeExpression(
        valueExpr: propertyExpr,
        customSchema: customSchemaExpression,
        context: context
      )
    else { return nil }

    return [
      "let \(raw: keyVariableName) = \(keyExpr)",
      "object[\(raw: keyVariableName)] = \(encodedExpr)"
    ]
  }

  private var hasDescriptionInOptions: Bool {
    guard let annotationArguments = annotationArguments else { return false }
    return annotationArguments.contains { argument in
      guard let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
        let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
      else { return false }
      return memberAccess.declName.baseName.text == "description"
    }
  }

  private func keyExpression(
    usingKeyStrategy: Bool,
    typeName: String,
    useSelfReference: Bool
  ) -> ExprSyntax {
    if let customKey = schemaCustomKey { return customKey }
    if usingKeyStrategy {
      if useSelfReference {
        return "Self.keyEncodingStrategy.encode(\"\(raw: identifier.text)\")"
      } else {
        return "\(raw: typeName).keyEncodingStrategy.encode(\"\(raw: identifier.text)\")"
      }
    }
    return "\"\(raw: identifier.text)\""
  }
}
