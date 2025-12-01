import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

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

  /// Validates schema options and emits diagnostics for invalid configurations
  func validateOptions(context: any MacroExpansionContext) {
    let diagnostics = SchemaOptionsDiagnostics(
      propertyName: identifier,
      propertyType: type,
      context: context
    )

    // Validate general SchemaOptions
    if let schemaOptions = annotationArguments {
      diagnostics.validateSchemaOptions(schemaOptions)
    }

    // Validate type-specific options
    if typeSpecificArguments != nil {
      let typeSpecificMacroNames = [
        "NumberOptions", "ArrayOptions", "ObjectOptions", "StringOptions",
      ]
      for macroName in typeSpecificMacroNames {
        if let arguments = attributes.arguments(for: macroName) {
          diagnostics.validateTypeSpecificOptions(arguments, macroName: macroName)
        }
      }
    }
  }

  func generateSchema(
    keyStrategy: ExprSyntax?,
    typeName: String,
    globalOptionalNulls: Bool = true,
    optionalNullUnion: CompositionKeyword,
    codingKeys: [String: String]? = nil,
    context: (any MacroExpansionContext)? = nil,
    selfReferenceAnchor: String? = nil,
    didUseSelfReference: inout Bool
  ) -> CodeBlockItemSyntax? {
    let sanitizedTypeName = typeName.trimmingBackticks()
    let referencesSelf =
      selfReferenceAnchor != nil && type.referencesType(named: sanitizedTypeName)

    var codeBlock: CodeBlockItemSyntax
    let typeInfo: TypeSyntax.TypeInformation
    if referencesSelf, let selfReferenceAnchor {
      didUseSelfReference = true
      typeInfo = type.typeInformation(
        selfTypeName: sanitizedTypeName,
        selfAnchor: selfReferenceAnchor
      )
    } else {
      typeInfo = type.typeInformation()
    }

    switch typeInfo {
    case .primitive(_, let code):
      codeBlock = code
      // Only use default value on primitives that can be `ExpressibleBy*Literal` to transform
      // from Swift type to JSONValue (required by .default())
      // In the future, JSONValue types should also be allowed to apply default value
      if let defaultValue {
        codeBlock = """
          \(codeBlock)
          .default(\(defaultValue.trimmed))
          """
      }
    case .schemable(_, let code): codeBlock = code
    case .notSupported:
      // Emit diagnostic for unsupported types
      if let context = context {
        let diagnostic = Diagnostic(
          node: identifier,
          message: UnsupportedTypeDiagnostic.propertyTypeNotSupported(
            propertyName: identifier.text,
            typeName: type.description.trimmingCharacters(in: .whitespaces)
          )
        )
        context.diagnose(diagnostic)
      }
      return nil
    }

    var customKey: ExprSyntax?
    var orNullStyle: ExprSyntax?
    let options: LabeledExprListSyntax? = annotationArguments.flatMap { args in
      let filtered = args.filter { argument in
        guard let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
          let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
        else { return true }

        if memberAccess.declName.baseName.text == "key" {
          customKey = functionCall.arguments.first?.expression
          return false
        }

        if memberAccess.declName.baseName.text == "orNull" {
          orNullStyle = functionCall.arguments.first?.expression
          return false
        }

        return true
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

    // Apply .orNull() if this is an optional property and:
    // 1. It has an explicit @SchemaOptions(.orNull(style:)) annotation, OR
    // 2. The global optionalNulls flag is true (default behavior)
    let hasOrNull = type.isOptional && (orNullStyle != nil || globalOptionalNulls)
    if hasOrNull {
      if let orNullStyle {
        // Explicit per-property annotation
        codeBlock = """
          \(codeBlock)
          .orNull(style: \(orNullStyle))
          """
      } else if globalOptionalNulls {
        // Global flag is true - use .type for primitives, configured union style otherwise
        let typeInfo = type.typeInformation()
        let style: String
        switch typeInfo {
        case .primitive(let primitive, _):
          // Use .type for scalar primitives, .union for arrays/dictionaries
          style = primitive.isScalar ? ".type" : optionalNullUnion.orNullStyleAccessor
        case .schemable:
          // Use union style for schemable types (objects)
          style = optionalNullUnion.orNullStyleAccessor
        case .notSupported:
          // Shouldn't reach here, but default to configured union style
          style = optionalNullUnion.orNullStyleAccessor
        }
        codeBlock = """
          \(codeBlock)
          .orNull(style: \(raw: style))
          """
      }
    }

    let keyExpr: ExprSyntax
    if let customKey {
      // Custom key from @SchemaOptions(.key(...)) takes highest priority
      keyExpr = customKey
    } else if let codingKeys, let codingKey = codingKeys[identifier.text] {
      // CodingKeys takes priority over keyStrategy
      keyExpr = "\"\(raw: codingKey)\""
    } else if keyStrategy != nil {
      // keyStrategy is used if no CodingKeys or custom key
      keyExpr = "\(raw: typeName).keyEncodingStrategy.encode(\"\(raw: identifier.text)\")"
    } else {
      // Default: use property name as-is
      keyExpr = "\"\(raw: identifier.text)\""
    }

    var block: CodeBlockItemSyntax = """
      JSONProperty(key: \(keyExpr)) { \(codeBlock) }
      """

    // When a property is optional AND has .orNull() applied, the output type becomes T??
    // because JSONProperty wraps the output in Optional, and .orNull() already returns Optional.
    // We need to flatten the double-optional with .flatMapOptional() to get back to T?
    if hasOrNull {
      block = """
        \(block)
        .flatMapOptional()
        """
    }

    if !type.isOptional {
      block = """
        \(block)
        .required()
        """
    }

    return block
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
}

/// Diagnostic messages for unsupported types
enum UnsupportedTypeDiagnostic: DiagnosticMessage {
  case propertyTypeNotSupported(propertyName: String, typeName: String)

  var message: String {
    switch self {
    case .propertyTypeNotSupported(let propertyName, let typeName):
      return """
        Property '\(propertyName)' has type '\(typeName)' which is not supported by the @Schemable macro. \
        This property will be excluded from the generated schema, which may cause the schema to not match \
        the memberwise initializer.
        """
    }
  }

  var diagnosticID: MessageID {
    switch self {
    case .propertyTypeNotSupported:
      return MessageID(domain: "JSONSchemaMacro", id: "unsupportedType")
    }
  }

  var severity: DiagnosticSeverity {
    .warning
  }
}
