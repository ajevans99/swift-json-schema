import SwiftSyntax

struct EnumSchemaGenerator {
  let name: TokenSyntax
  let members: MemberBlockItemListSyntax
  let attributes: AttributeListSyntax

  init(fromEnum enumDecl: EnumDeclSyntax) {
    name = enumDecl.name
    members = enumDecl.memberBlock.members
    attributes = enumDecl.attributes
  }

  func makeSchema() -> DeclSyntax {
    let schemableCases = members.schemableEnumCases()

    let casesWithoutAssociatedValues = schemableCases.filter { $0.associatedValues == nil }
    let casesWithAssociatedValues = schemableCases.filter { $0.associatedValues != nil }

    var codeBlockItem: CodeBlockItemSyntax

    if !casesWithAssociatedValues.isEmpty {
      // When any case has an associated value, use composition and any of to build schema with nested objects
      let statements = casesWithAssociatedValues.compactMap { $0.generateSchema() }
      var codeBlockItemList = CodeBlockItemListSyntax(statements)

      // Add cases without associated value
      if !casesWithoutAssociatedValues.isEmpty {
        let statements = casesWithoutAssociatedValues.compactMap { $0.generateSchema() }
        codeBlockItemList.append("JSONEnum { \(CodeBlockItemListSyntax(statements)) }")
      }
      codeBlockItem = "JSONComposition.AnyOf { \(codeBlockItemList) }"
    } else {
      // When no case has an associated value, use simple enum schema
      let statements = casesWithoutAssociatedValues.compactMap { $0.generateSchema() }
      codeBlockItem = "JSONEnum { \(CodeBlockItemListSyntax(statements)) }"
    }

    if let annotationArguments = attributes.arguments(for: "SchemaOptions") {
      codeBlockItem.applyArguments(annotationArguments)
    }

    let variableDecl: DeclSyntax = """
      static var schema: some JSONSchemaComponent<\(name)> {
        \(codeBlockItem)
      }
      """

    return variableDecl
  }
}

struct SchemaGenerator {
  let name: TokenSyntax
  let members: MemberBlockItemListSyntax
  let attributes: AttributeListSyntax

  init(fromClass classDecl: ClassDeclSyntax) {
    name = classDecl.name.trimmed
    members = classDecl.memberBlock.members
    attributes = classDecl.attributes
  }

  init(fromStruct structDecl: StructDeclSyntax) {
    name = structDecl.name.trimmed
    members = structDecl.memberBlock.members
    attributes = structDecl.attributes
  }

  func makeSchema() -> DeclSyntax {
    let schemableMembers = members.schemableMembers()

    let statements = schemableMembers.compactMap { $0.generateSchema() }

    var codeBlockItem: CodeBlockItemSyntax = "JSONObject { \(CodeBlockItemListSyntax(statements)) }"

    if let annotationArguments = attributes.arguments(for: "SchemaOptions") {
      codeBlockItem.applyArguments(annotationArguments)
    }

    if let objectArguemnts = attributes.arguments(for: "ObjectOptions") {
      codeBlockItem.applyArguments(objectArguemnts)
    }

    let variableDecl: DeclSyntax = """
      static var schema: some JSONSchemaComponent<\(name)> {
        JSONSchema(\(name).init) { \(codeBlockItem) }
      }
      """

    return variableDecl
  }
}
