import SwiftSyntax

struct SchemableEnumCase {
  let identifier: TokenSyntax
  let associatedValues: EnumCaseParameterListSyntax?
  let rawValue: String?

  init(enumCaseDecl: EnumCaseDeclSyntax, caseElement: EnumCaseElementSyntax, isStringBacked: Bool) {
    identifier = caseElement.name.trimmed
    associatedValues = caseElement.parameterClause?.parameters

    // Extract raw value if present (for String-backed enums)
    if let rawValueExpr = caseElement.rawValue?.value.as(StringLiteralExprSyntax.self) {
      // Explicit raw value
      rawValue = rawValueExpr.segments
        .compactMap { segment -> String? in
          if case .stringSegment(let stringSegment) = segment {
            return stringSegment.content.text
          }
          return nil
        }
        .joined()
    } else if isStringBacked {
      // Implicit raw value: use the case name (without backticks) for String-backed enums
      rawValue = identifier.text.trimmingBackticks()
    } else {
      rawValue = nil
    }
  }

  func generateSchema() -> CodeBlockItemSyntax? {
    guard let associatedValues else {
      // Use raw value if present, otherwise use case name (without backticks)
      let enumValue = rawValue ?? identifier.text.trimmingBackticks()
      return """
        "\(raw: enumValue)"
        """
    }
    let properties: [CodeBlockItemSyntax] = associatedValues.enumerated()
      .compactMap { index, parameter in
        let key = parameter.firstName?.text ?? "_\(index)"

        let typeInfo = parameter.type.typeInformation()
        var codeBlock: CodeBlockItemSyntax

        switch typeInfo {
        case .primitive(_, schema: let code):
          if let defaultValue = parameter.defaultValue?.value {
            codeBlock = """
              \(code)
              .default(\(defaultValue))
              """
          } else {
            codeBlock = code
          }
        case .schemable(_, schema: let code): codeBlock = code
        case .notSupported: return nil
        }

        // Add description if available
        if let docString = parameter.docString {
          codeBlock = """
            \(codeBlock)
            .description(\(literal: docString))
            """
        }

        var block: CodeBlockItemSyntax = """
          JSONProperty(key: "\(raw: key)") { \(codeBlock) }
          """

        if !parameter.type.isOptional {
          block = """
            \(block)
            .required()
            """
        }

        return block
      }

    let mapExpressionList = LabeledExprListSyntax {
      for (index, parameter) in associatedValues.enumerated() {
        if let label = parameter.firstName, label.text != "_" {
          LabeledExprSyntax(
            label: label.trimmed,
            colon: .colonToken(trailingTrivia: .space),
            expression: DeclReferenceExprSyntax(baseName: "$\(raw: index)")
          )
        } else {
          LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: "$\(raw: index)"))
        }
      }
    }

    let list = CodeBlockItemListSyntax(properties)

    let property: CodeBlockItemSyntax = """
      JSONProperty(key: "\(raw: identifier.text)") { JSONObject { \(list) } }
      .required()
      """

    return """
      JSONObject { \(property) }
      .map {
        Self.\(identifier)(\(mapExpressionList))
      }
      """
  }
}
