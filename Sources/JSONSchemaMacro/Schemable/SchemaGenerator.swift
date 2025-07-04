import SwiftSyntax
import SwiftSyntaxBuilder

struct EnumSchemaGenerator {
  let declModifier: DeclModifierSyntax?
  let name: TokenSyntax
  let members: MemberBlockItemListSyntax
  let attributes: AttributeListSyntax

  init(fromEnum enumDecl: EnumDeclSyntax) {
    declModifier = enumDecl.modifiers.first
    name = enumDecl.name.trimmed
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
        codeBlockItemList.append(simpleEnumSchema(for: casesWithoutAssociatedValues))
      }
      codeBlockItem = "JSONComposition.OneOf(into: \(name).self) { \(codeBlockItemList) }"
    } else {
      // When no case has an associated value, use simple enum schema
      codeBlockItem = simpleEnumSchema(for: casesWithoutAssociatedValues)
    }

    if let annotationArguments = attributes.arguments(for: "SchemaOptions") {
      codeBlockItem = SchemaOptionsGenerator.apply(
        annotationArguments,
        to: codeBlockItem,
        for: "SchemaOptions"
      )
    }

    let variableDecl: DeclSyntax = """
      \(declModifier)static var schema: some JSONSchemaComponent<\(name)> {
        \(codeBlockItem)
      }
      """

    return variableDecl
  }

  /// Generates code block schema for cases without associated values.
  private func simpleEnumSchema(
    for casesWithoutAssociatedValues: [SchemableEnumCase]
  ) -> CodeBlockItemSyntax {
    let statements = casesWithoutAssociatedValues.compactMap { $0.generateSchema() }
    let statementList = CodeBlockItemListSyntax(statements, separator: .newline)

    var switchCases = casesWithoutAssociatedValues.map(\.identifier)
      .map { identifier -> SwitchCaseSyntax in
        """
        case \"\(identifier)\":
          return Self.\(identifier)

        """
      }
    switchCases.append("default: return nil")
    let switchCaseList = SwitchCaseListSyntax(switchCases.map { .switchCase($0) })

    return """
      JSONString()  
        .enumValues {
          \(statementList)
        }
        .compactMap {
          switch $0 {
          \(switchCaseList)
          }
        }
      """
  }
}

struct SchemaGenerator {
  let declModifier: DeclModifierSyntax?
  let name: TokenSyntax
  let members: MemberBlockItemListSyntax
  let attributes: AttributeListSyntax
  let keyStrategy: ExprSyntax?

  init(fromClass classDecl: ClassDeclSyntax, keyStrategy: ExprSyntax?) {
    declModifier = classDecl.modifiers.first
    name = classDecl.name.trimmed
    members = classDecl.memberBlock.members
    attributes = classDecl.attributes
    self.keyStrategy = keyStrategy
  }

  init(fromStruct structDecl: StructDeclSyntax, keyStrategy: ExprSyntax?) {
    declModifier = structDecl.modifiers.first
    name = structDecl.name.trimmed
    members = structDecl.memberBlock.members
    attributes = structDecl.attributes
    self.keyStrategy = keyStrategy
  }

  func makeSchema() -> DeclSyntax {
    let schemableMembers = members.schemableMembers()

    let statements = schemableMembers.compactMap {
      $0.generateSchema(keyStrategy: keyStrategy, typeName: name.text)
    }

    var codeBlockItem: CodeBlockItemSyntax =
      "JSONObject { \(CodeBlockItemListSyntax(statements, separator: .newline)) }"

    if let annotationArguments = attributes.arguments(for: "SchemaOptions") {
      codeBlockItem = SchemaOptionsGenerator.apply(
        annotationArguments,
        to: codeBlockItem,
        for: "SchemaOptions"
      )
    }

    if let objectArguments = attributes.arguments(for: "ObjectOptions") {
      codeBlockItem = SchemaOptionsGenerator.apply(
        objectArguments,
        to: codeBlockItem,
        for: "ObjectOptions"
      )
    }

    let variableDecl: DeclSyntax = """
      \(declModifier)static var schema: some JSONSchemaComponent<\(name)> {
        JSONSchema(\(name).init) { \(codeBlockItem) }
      }
      """

    return variableDecl
  }
}
