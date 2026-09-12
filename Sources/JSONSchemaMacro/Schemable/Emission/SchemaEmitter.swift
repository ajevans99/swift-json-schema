import SwiftSyntax
import SwiftSyntaxBuilder

enum SchemaEmitter {
  static func declarations(for plan: SchemaPlan) -> [DeclSyntax] {
    let declaration = plan.declaration
    let schema: DeclSyntax
    switch plan.body {
    case .object(let members):
      let expression = objectExpression(members.compactMap(\.included), declaration: declaration)
      schema = """
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        \(declaration.accessModifier)static var schema: some JSONSchemaComponent<\(declaration.name)> {
          JSONSchema(\(declaration.name).init) { \(expression) }
        }
        """
    case .enumeration(let cases):
      let expression = enumExpression(
        cases,
        declaration: declaration,
        configuration: plan.configuration
      )
      schema = """
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        \(declaration.accessModifier)static var schema: some JSONSchemaComponent<\(declaration.name)> {
          \(expression)
        }
        """
    }
    var declarations: [DeclSyntax] = [schema]
    if let strategy = plan.configuration.keyStrategy {
      declarations.append(
        """
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        \(declaration.accessModifier)static var keyEncodingStrategy: KeyEncodingStrategies { \(strategy) }
        """
      )
    }
    return declarations
  }

  private static func objectExpression(
    _ members: [PlannedMember],
    declaration: SchemableDeclaration
  ) -> CodeBlockItemSyntax {
    let statements = CodeBlockItemListSyntax(
      members.map {
        FieldEmitter.codeBlock(for: $0.field, multilineDescription: true)
      },
      separator: .newline
    )
    var expression: CodeBlockItemSyntax = "JSONObject { \(statements) }"
    expression = SchemaOptionsGenerator.apply(
      declaration.options.options(for: .schema, .object),
      to: expression
    )
    if members.contains(where: { $0.field.usesSelfReference }) {
      expression = """
        \(expression)
        .dynamicAnchor(Self.defaultAnchor)
        """
    }
    return expression
  }

  private static func enumExpression(
    _ cases: [EnumCasePlan],
    declaration: SchemableDeclaration,
    configuration: MacroConfiguration
  ) -> CodeBlockItemSyntax {
    var simple: [SchemableEnumCase] = []
    var payloads: [CodeBlockItemSyntax] = []
    for enumCase in cases {
      switch enumCase {
      case .simple(let source): simple.append(source)
      case .payload(let source, let fields):
        payloads.append(payloadExpression(source, fields: fields))
      case .unsupported:
        break
      }
    }
    let expression: CodeBlockItemSyntax
    if payloads.isEmpty {
      expression = simpleEnumExpression(simple)
    } else {
      if !simple.isEmpty { payloads.append(simpleEnumExpression(simple)) }
      let statements = CodeBlockItemListSyntax(payloads)
      expression = """
        JSONComposition.\(raw: configuration.enumComposition.jsonCompositionBuilderName)(into: \(declaration.name).self) { \(statements) }
        """
    }
    return SchemaOptionsGenerator.apply(declaration.options.options(for: .schema), to: expression)
  }

  private static func simpleEnumExpression(_ cases: [SchemableEnumCase]) -> CodeBlockItemSyntax {
    let statements = CodeBlockItemListSyntax(
      cases.map {
        let value: CodeBlockItemSyntax =
          "\(literal: $0.rawValue ?? $0.identifier.text.trimmingBackticks())"
        return value
      },
      separator: .newline
    )
    var switchCases = cases.map { enumCase -> SwitchCaseSyntax in
      """
      case \(literal: enumCase.rawValue ?? enumCase.identifier.text.trimmingBackticks()):
        return Self.\(enumCase.identifier)

      """
    }
    switchCases.append("default: return nil")
    let switchCaseList = SwitchCaseListSyntax(switchCases.map { .switchCase($0) })
    return """
      JSONString()
        .enumValues {
          \(statements)
        }
        .compactMap {
          switch $0 {
          \(switchCaseList)
          }
        }
      """
  }

  private static func payloadExpression(
    _ enumCase: SchemableEnumCase,
    fields: [PayloadField]
  ) -> CodeBlockItemSyntax {
    let statements = CodeBlockItemListSyntax(
      fields.map { FieldEmitter.codeBlock(for: $0.field) }
    )
    let arguments = LabeledExprListSyntax {
      for (index, field) in fields.enumerated() {
        LabeledExprSyntax(
          label: field.label,
          colon: field.label == nil ? nil : .colonToken(trailingTrivia: .space),
          expression: DeclReferenceExprSyntax(baseName: "$\(raw: index)")
        )
      }
    }
    let property: CodeBlockItemSyntax = """
      JSONProperty(key: \(literal: enumCase.identifier.text.trimmingBackticks())) { JSONObject { \(statements) } }
      .required()
      """
    return """
      JSONObject { \(property) }
      .map {
        Self.\(enumCase.identifier)(\(arguments))
      }
      """
  }
}
