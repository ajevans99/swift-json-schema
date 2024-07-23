import SwiftSyntax

struct SchemableEnumCase {
  let identifier: TokenSyntax
  let associatedValues: EnumCaseParameterListSyntax?

  init(enumCaseDecl: EnumCaseDeclSyntax, caseElement: EnumCaseElementSyntax) {
    identifier = caseElement.name
    associatedValues = caseElement.parameterClause?.parameters
  }

  func generateSchema() -> CodeBlockItemSyntax? {
    guard let associatedValues else {
      return """
        "\(raw: identifier.text)"
        """
    }
    let properties: [CodeBlockItemSyntax] = associatedValues.enumerated()
      .compactMap { index, parameter in
        let key = parameter.firstName?.text ?? "_\(index)"

        let typeInfo = parameter.type.typeInformation()
        let codeBlock: CodeBlockItemSyntax

        switch typeInfo {
        case .primative(_, schema: let code):
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

        return """
          JSONProperty(key: "\(raw: key)") { \(codeBlock) }
          """
      }

    let list = CodeBlockItemListSyntax(properties)

    return """
      JSONObject { JSONProperty(key: "\(raw: identifier.text)") { JSONObject { \(list) } } }
      """
  }
}
