import Foundation
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
    var customKey: ExprSyntax?
    var customFormat: ExprSyntax?
    
    // Check for custom key and format options first
    let options: LabeledExprListSyntax? = annotationArguments.flatMap { args in
      let filtered = args.filter { argument in
        guard let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
          let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
        else { return true }

        if memberAccess.declName.baseName.text == "key" {
          customKey = functionCall.arguments.first?.expression
          return false
        }
        
        if memberAccess.declName.baseName.text == "format" {
          customFormat = functionCall.arguments.first?.expression
          return false
        }

        return true
      }
      return filtered.isEmpty ? nil : LabeledExprListSyntax(filtered)
    }
    
    var codeBlock: CodeBlockItemSyntax
    
    // If format is specified, use JSONString with format and type conversion
    if let customFormat {
      let baseTypeName = type.baseTypeName()
      
      // Extract format string by removing quotes
      let formatString = customFormat.description.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\"", with: "")
      
      // Generate appropriate conversion based on format and type
      let conversion: String
      switch (baseTypeName, formatString) {
      case ("UUID", "uuid"):
        conversion = "UUID(uuidString: $0)!"
      case ("Date", "date-time"):
        conversion = "ISO8601DateFormatter().date(from: $0)!"
      default:
        // Generic fallback for string-based formats
        conversion = "\(baseTypeName)($0)"
      }
      
      // Start with basic JSONString with format
      var innerCodeBlock: CodeBlockItemSyntax = """
        JSONString()
        .format(\(customFormat))
        """
      
      // Apply other schema options to the inner JSONString
      if let options, !options.isEmpty {
        innerCodeBlock = SchemaOptionsGenerator.apply(
          options,
          to: innerCodeBlock,
          for: "SchemaOptions"
        )
      }
      
      codeBlock = """
        JSONSchema({ \(raw: conversion) }) {
          \(innerCodeBlock)
        }
        """
    } else {
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
    }

    // Apply schema options if present (but skip if we already applied them in format case)
    if let options, !options.isEmpty, customFormat == nil {
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

    let keyExpr: ExprSyntax
    if let customKey {
      keyExpr = customKey
    } else if keyStrategy != nil {
      keyExpr = "\(raw: typeName).keyEncodingStrategy.encode(\"\(raw: identifier.text)\")"
    } else {
      keyExpr = "\"\(raw: identifier.text)\""
    }

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
