import SwiftSyntax

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
