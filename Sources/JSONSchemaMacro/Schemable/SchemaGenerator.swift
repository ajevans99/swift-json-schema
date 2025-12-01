import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension String {
  /// Removes backticks from Swift identifiers (e.g., "`default`" → "default")
  func trimmingBackticks() -> String {
    if self.hasPrefix("`") && self.hasSuffix("`") {
      return String(self.dropFirst().dropLast())
    }
    return self
  }
}

struct EnumSchemaGenerator {
  let declModifier: DeclModifierSyntax?
  let name: TokenSyntax
  let members: MemberBlockItemListSyntax
  let attributes: AttributeListSyntax
  let isStringBacked: Bool
  let composition: CompositionKeyword

  init(
    fromEnum enumDecl: EnumDeclSyntax,
    accessLevel: String? = nil,
    composition: CompositionKeyword
  ) {
    // Use provided access level if available, otherwise use the declaration's modifier
    if let accessLevel {
      // Create modifier with trailing space for proper formatting
      declModifier = DeclModifierSyntax(
        name: .identifier(accessLevel),
        trailingTrivia: .space
      )
    } else {
      declModifier = enumDecl.modifiers.first
    }
    name = enumDecl.name.trimmed
    members = enumDecl.memberBlock.members
    attributes = enumDecl.attributes
    self.composition = composition

    // Check if enum inherits from String
    isStringBacked =
      enumDecl.inheritanceClause?.inheritedTypes
      .contains { type in
        type.type.as(IdentifierTypeSyntax.self)?.name.text == "String"
      } ?? false
  }

  func makeSchema() -> DeclSyntax {
    let schemableCases = members.schemableEnumCases(isStringBacked: isStringBacked)

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
      codeBlockItem =
        "JSONComposition.\(raw: composition.jsonCompositionBuilderName)(into: \(name).self) { \(codeBlockItemList) }"
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
      @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

    var switchCases =
      casesWithoutAssociatedValues
      .map { enumCase -> SwitchCaseSyntax in
        // Use raw value if present, otherwise use case name (without backticks)
        let matchValue = enumCase.rawValue ?? enumCase.identifier.text.trimmingBackticks()
        return """
          case "\(raw: matchValue)":
            return Self.\(enumCase.identifier)

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
  let optionalNulls: Bool
  let optionalNullUnion: CompositionKeyword
  let context: (any MacroExpansionContext)?

  init(
    fromClass classDecl: ClassDeclSyntax,
    keyStrategy: ExprSyntax?,
    optionalNulls: Bool = true,
    accessLevel: String? = nil,
    context: (any MacroExpansionContext)? = nil,
    optionalNullUnion: CompositionKeyword
  ) {
    // Use provided access level if available, otherwise use the declaration's modifier
    if let accessLevel {
      // Create modifier with trailing space for proper formatting
      declModifier = DeclModifierSyntax(
        name: .identifier(accessLevel),
        trailingTrivia: .space
      )
    } else {
      declModifier = classDecl.modifiers.first
    }
    name = classDecl.name.trimmed
    members = classDecl.memberBlock.members
    attributes = classDecl.attributes
    self.keyStrategy = keyStrategy
    self.optionalNulls = optionalNulls
    self.context = context
    self.optionalNullUnion = optionalNullUnion
  }

  init(
    fromStruct structDecl: StructDeclSyntax,
    keyStrategy: ExprSyntax?,
    optionalNulls: Bool = true,
    accessLevel: String? = nil,
    context: (any MacroExpansionContext)? = nil,
    optionalNullUnion: CompositionKeyword
  ) {
    // Use provided access level if available, otherwise use the declaration's modifier
    if let accessLevel {
      // Create modifier with trailing space for proper formatting
      declModifier = DeclModifierSyntax(
        name: .identifier(accessLevel),
        trailingTrivia: .space
      )
    } else {
      declModifier = structDecl.modifiers.first
    }
    name = structDecl.name.trimmed
    members = structDecl.memberBlock.members
    attributes = structDecl.attributes
    self.keyStrategy = keyStrategy
    self.optionalNulls = optionalNulls
    self.context = context
    self.optionalNullUnion = optionalNullUnion
  }

  func makeSchema() -> DeclSyntax {
    let schemableMembers = members.schemableMembers()
    let codingKeys = members.extractCodingKeys()
    let anchorName = {
      let trimmed = name.text.trimmingBackticks()
      return trimmed.isEmpty ? name.text : trimmed
    }()

    // Emit diagnostics for potential memberwise init mismatches
    if let context = context {
      let diagnostics = InitializerDiagnostics(
        typeName: name,
        members: members,
        context: context
      )
      diagnostics.emitDiagnostics(for: schemableMembers)

      // Validate schema options for each member
      for member in schemableMembers {
        member.validateOptions(context: context)
      }
    }

    var usesSelfReference = false
    let statements = schemableMembers.compactMap {
      $0.generateSchema(
        keyStrategy: keyStrategy,
        typeName: name.text,
        globalOptionalNulls: optionalNulls,
        optionalNullUnion: optionalNullUnion,
        codingKeys: codingKeys,
        context: context,
        selfReferenceAnchor: anchorName,
        didUseSelfReference: &usesSelfReference
      )
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

    if usesSelfReference {
      codeBlockItem = """
        \(codeBlockItem)
        .dynamicAnchor(Self.defaultAnchor)
        """
    }

    let variableDecl: DeclSyntax = """
      @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
      \(declModifier)static var schema: some JSONSchemaComponent<\(name)> {
        JSONSchema(\(name).init) { \(codeBlockItem) }
      }
      """

    return variableDecl
  }
}
