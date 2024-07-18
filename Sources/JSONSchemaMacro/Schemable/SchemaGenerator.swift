import SwiftSyntax

struct SchemaGenerator {
  let members: MemberBlockItemListSyntax
  let attributes: AttributeListSyntax

  init(fromClass classDecl: ClassDeclSyntax) {
    members = classDecl.memberBlock.members
    attributes = classDecl.attributes
  }

  init(fromStruct structDecl: StructDeclSyntax) {
    members = structDecl.memberBlock.members
    attributes = structDecl.attributes
  }

  func makeSchema() -> DeclSyntax {
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
          requiredMemebers.enumerated()
            .map {
              (
                index: $0.offset,
                expression: StringLiteralExprSyntax(content: $0.element.identifier.text)
              )
            }
            .map {
              ArrayElementSyntax(
                expression: $0.expression,
                trailingComma: .commaToken(
                  presence: $0.index == requiredMemebers.indices.last ? .missing : .present
                )
              )
            }
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

}
