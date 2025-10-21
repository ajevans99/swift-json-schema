import SwiftSyntax
import SwiftSyntaxBuilder

struct EnumSchemaGenerator {
  let accessModifier: String
  let name: TokenSyntax
  let members: MemberBlockItemListSyntax
  let attributes: AttributeListSyntax

  init(fromEnum enumDecl: EnumDeclSyntax, accessModifier: String) {
    self.accessModifier = accessModifier
    self.name = enumDecl.name.trimmed
    self.members = enumDecl.memberBlock.members
    self.attributes = enumDecl.attributes
  }

  func makeSchema() -> DeclSyntax {
    let schemableCases = members.schemableEnumCases()

    let casesWithoutAssociatedValues = schemableCases.filter { $0.associatedValues == nil }
    let casesWithAssociatedValues = schemableCases.filter { $0.associatedValues != nil }

    var codeBlockItem: CodeBlockItemSyntax

    if !casesWithAssociatedValues.isEmpty {
      let statements = casesWithAssociatedValues.compactMap { $0.generateSchema() }
      var codeBlockItemList = CodeBlockItemListSyntax(statements)

      if !casesWithoutAssociatedValues.isEmpty {
        codeBlockItemList.append(simpleEnumSchema(for: casesWithoutAssociatedValues))
      }
      codeBlockItem = "JSONComposition.OneOf(into: \(name).self) { \(codeBlockItemList) }"
    } else {
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
      \(raw: accessModifier)static var schema: some JSONSchemaComponent<\(name)> {
        \(codeBlockItem)
      }
      """

    return variableDecl
  }

  func makeEncodingDeclarations() -> [DeclSyntax] {
    let schemableCases = members.schemableEnumCases()
    let encodingCases = schemableCases.compactMap { $0.generateEncodingCase(enumName: name) }

    let encodeDecl: DeclSyntax
    if encodingCases.count == schemableCases.count, !encodingCases.isEmpty {
      let switchCaseList = SwitchCaseListSyntax(encodingCases.map { .switchCase($0) })
      encodeDecl = """
        \(raw: accessModifier)static func encode(_ value: \(name)) -> JSONValue {
          switch value {
          \(switchCaseList)
          }
        }
        """
    } else {
      encodeDecl = """
        \(raw: accessModifier)static func encode(_ value: \(name)) -> JSONValue {
          preconditionFailure("Encoding for enum \(raw: name.text) is not supported")
        }
        """
    }

    let instanceDecl: DeclSyntax = """
      \(raw: accessModifier)func toJSONValue() -> JSONValue {
        Self.encode(self)
      }
      """

    return [encodeDecl, instanceDecl]
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
  let accessModifier: String
  let name: TokenSyntax
  let members: MemberBlockItemListSyntax
  let attributes: AttributeListSyntax
  let keyStrategy: ExprSyntax?

  init(
    fromClass classDecl: ClassDeclSyntax,
    keyStrategy: ExprSyntax?,
    accessModifier: String
  ) {
    self.accessModifier = accessModifier
    self.name = classDecl.name.trimmed
    self.members = classDecl.memberBlock.members
    self.attributes = classDecl.attributes
    self.keyStrategy = keyStrategy
  }

  init(
    fromStruct structDecl: StructDeclSyntax,
    keyStrategy: ExprSyntax?,
    accessModifier: String
  ) {
    self.accessModifier = accessModifier
    self.name = structDecl.name.trimmed
    self.members = structDecl.memberBlock.members
    self.attributes = structDecl.attributes
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
      \(raw: accessModifier)static var schema: some JSONSchemaComponent<\(name)> {
        JSONSchema(\(name).init) { \(codeBlockItem) }
      }
      """

    return variableDecl
  }

  func makeEncodingDeclarations() -> [DeclSyntax] {
    let schemableMembers = members.schemableMembers()
    var statements: [CodeBlockItemSyntax] = [
      "var object: [String: JSONValue] = [:]"
    ]

    for (index, member) in schemableMembers.enumerated() {
      if let encodingStatements = member.generateEncodingStatements(
        hasKeyStrategy: keyStrategy != nil,
        typeName: name,
        keyIndex: index
      ) {
        statements.append(contentsOf: encodingStatements)
      } else {
        let failurePath = "\(name.text).\(member.identifier.text)"
        statements.append(
          """
          preconditionFailure("Encoding for property \(raw: failurePath) is not supported")
          """
        )
      }
    }

    statements.append("return JSONValue.object(object)")

    let encodeDecl: DeclSyntax = """
      \(raw: accessModifier)static func encode(_ value: \(name)) -> JSONValue {
        \(CodeBlockItemListSyntax(statements, separator: .newline))
      }
      """

    let instanceDecl: DeclSyntax = """
      \(raw: accessModifier)func toJSONValue() -> JSONValue {
        Self.encode(self)
      }
      """

    return [encodeDecl, instanceDecl]
  }
}
