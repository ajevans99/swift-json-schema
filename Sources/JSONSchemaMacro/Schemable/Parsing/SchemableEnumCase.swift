import SwiftSyntax

struct SchemableEnumCase {
  let identifier: TokenSyntax
  let associatedValues: EnumCaseParameterListSyntax?
  let rawValue: String?

  init(enumCaseDecl: EnumCaseDeclSyntax, caseElement: EnumCaseElementSyntax, isStringBacked: Bool) {
    identifier = caseElement.name.trimmed
    associatedValues = caseElement.parameterClause?.parameters
    if let rawValueExpr = caseElement.rawValue?.value.as(StringLiteralExprSyntax.self) {
      rawValue = rawValueExpr.representedLiteralValue
    } else if isStringBacked {
      rawValue = identifier.text.trimmingBackticks()
    } else {
      rawValue = nil
    }
  }
}
