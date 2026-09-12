import SwiftBasicFormat
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import JSONSchemaMacro

struct SchemaPlanningTests {
  private func plan(_ source: String, arguments: String = "") throws -> SchemaPlan {
    let file = Parser.parse(source: source)
    let declaration = try #require(file.statements.first?.item.as(DeclSyntax.self))
    let configuration = try MacroConfiguration(
      attribute: AttributeSyntax("@Schemable(\(raw: arguments))")
    )
    let parsed: SchemableDeclaration
    if let value = declaration.as(StructDeclSyntax.self) {
      parsed = try SchemableDeclaration(value, lexicalContext: [])
    } else if let value = declaration.as(ClassDeclSyntax.self) {
      parsed = try SchemableDeclaration(value, lexicalContext: [])
    } else {
      let value = try #require(declaration.as(EnumDeclSyntax.self))
      parsed = try SchemableDeclaration(value, lexicalContext: [])
    }
    return SchemaPlanner.plan(parsed, configuration: configuration)
  }

  private func fields(_ plan: SchemaPlan) throws -> [FieldPlan] {
    guard case .object(let members) = plan.body else {
      Issue.record("Expected an object plan")
      return []
    }
    return members.compactMap(\.included).map(\.field)
  }

  @Test func keyPrecedenceAndNullabilityAreResolvedBeforeEmission() throws {
    let plan = try plan(
      """
      struct Example {
        @SchemaOptions(.key("custom"), .orNull(style: .unionAnyOf))
        let first: Optional<String>
        let second: Int
        let third: Swift.Optional<Array<String>>
        enum CodingKeys: String {
          case first = "ignored"
          case second = "coded"
        }
      }
      """,
      arguments: "keyStrategy: .snakeCase"
    )
    let fields = try fields(plan)
    #expect(fields.count == 3)
    #expect(fields[0].key.trimmedDescription == "\"custom\"")
    #expect(fields[0].nullStyle?.trimmedDescription == ".unionAnyOf")
    #expect(!fields[0].isRequired)
    #expect(fields[1].key.trimmedDescription == "\"coded\"")
    #expect(fields[1].isRequired)
    #expect(fields[1].nullStyle == nil)
    #expect(fields[2].key.trimmedDescription == "Example.keyEncodingStrategy.encode(\"third\")")
    #expect(fields[2].nullStyle?.trimmedDescription == ".union")
  }

  @Test func customSchemaPreservesOrderedReplacement() throws {
    let plan = try plan(
      """
      struct Example {
        @SchemaOptions(.title("discarded"), .customSchema(Custom.self), .description("kept"))
        let value: String
      }
      """
    )
    let field = try #require(try fields(plan).first)
    guard case .custom(let value) = field.base else {
      Issue.record("Expected a custom base")
      return
    }
    #expect(value.trimmedDescription == "Custom.self")
    #expect(field.modifiers.map(\.name.text) == ["description"])
    #expect(field.description == nil)
    #expect(field.defaultValue == nil)
  }

  @Test(arguments: [
    ("String", "StringOptions", "minLength", "maxLength"),
    ("Int", "NumberOptions", "minimum", "maximum"),
    ("[String]", "ArrayOptions", "minItems", "maxItems"),
    ("Value", "ObjectOptions", "minProperties", "maxProperties"),
  ])
  func customSchemaPreservesPropertyAttributeOrder(
    type: String,
    attribute: String,
    before: String,
    after: String
  ) throws {
    let plan = try plan(
      """
      struct Example {
        @\(attribute)(.\(before)(1))
        @SchemaOptions(.comment("discarded"), .customSchema(Custom.self), .description("kept"))
        @\(attribute)(.\(after)(4))
        @SchemaOptions(.title("last"))
        let value: \(type)
      }
      """
    )
    let field = try #require(try fields(plan).first)
    guard case .custom(let value) = field.base else {
      Issue.record("Expected a custom base")
      return
    }
    #expect(plan.diagnostics.isEmpty)
    #expect(value.trimmedDescription == "Custom.self")
    #expect(field.modifiers.map(\.name.text) == ["description", after, "title"])
  }

  @Test(arguments: ["struct", "final class"])
  func customSchemaPreservesDeclarationAttributeOrder(kind: String) throws {
    let plan = try plan(
      """
      @ObjectOptions(.minProperties(2))
      @SchemaOptions(.comment("discarded"), .customSchema(Custom.self), .description("kept"))
      @ObjectOptions(.maxProperties(4))
      @SchemaOptions(.title("last"))
      \(kind) Example {
        let value: String
        init(value: String) { self.value = value }
      }
      """
    )
    #expect(plan.diagnostics.isEmpty)
    let declaration = try #require(SchemaEmitter.declarations(for: plan).first)
    #expect(
      declaration.formatted(using: BasicFormat(indentationWidth: .spaces(2))).trimmedDescription
        == """
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        static var schema: some JSONSchemaComponent<Example> {
          JSONSchema(Example.init) {
            Custom.self.schema
            .description("kept")
            .maxProperties(4)
            .title("last")
          }
        }
        """
    )
  }

  @Test(arguments: ["", "keyStrategy: nil"])
  func absentKeyStrategyPreservesDefaultKeyPrecedence(arguments: String) throws {
    let plan = try plan(
      """
      struct Example {
        @SchemaOptions(.key("custom"))
        let firstName: String
        let lastName: String
        let displayName: String
        enum CodingKeys: String {
          case firstName = "ignored"
          case lastName = "coded"
        }
      }
      """,
      arguments: arguments
    )
    #expect(plan.diagnostics.isEmpty)
    #expect(plan.configuration.keyStrategy == nil)
    #expect(
      try fields(plan).map(\.key.trimmedDescription) == [
        "\"custom\"", "\"coded\"", "\"displayName\"",
      ]
    )
    #expect(SchemaEmitter.declarations(for: plan).count == 1)
  }

  @Test func customSchemaDoesNotLeaveUnusedSelfReference() throws {
    let plan = try plan(
      """
      struct Node {
        @SchemaOptions(.customSchema(Replacement.self))
        let child: Node?
      }
      """
    )
    let field = try #require(try fields(plan).first)
    #expect(!field.usesSelfReference)
    #expect(field.nullStyle?.trimmedDescription == ".union")
  }

  @Test func allTypeSpecificGroupsShareParsingAndEmission() throws {
    let plan = try plan(
      """
      struct Example {
        @NumberOptions(.minimum(0))
        @StringOptions(.minLength(2))
        let value: Int
      }
      """
    )
    let field = try #require(try fields(plan).first)
    #expect(field.modifiers.map(\.name.text) == ["minimum", "minLength"])
    #expect(plan.diagnostics.count == 1)
    #expect(plan.diagnostics.first?.message.contains("@StringOptions") == true)
  }

  @Test func initializerUsesOnlyIncludedFields() throws {
    let plan = try plan(
      """
      struct Example {
        let name: String
        let callback: () -> Void
        @ExcludeFromSchema let ignored: Int
        init(name: String) {}
      }
      """
    )
    guard case .object(let members) = plan.body else {
      Issue.record("Expected object plan")
      return
    }
    #expect(members.count == 3)
    guard case .included = members[0], case .unsupported = members[1],
      case .excluded = members[2]
    else {
      Issue.record("Expected explicit included, unsupported, and excluded results")
      return
    }
    #expect(plan.diagnostics.count == 1)
    #expect(plan.diagnostics.first?.message.contains("callback") == true)
  }

  @Test func unsupportedEnumPayloadNeverProducesPartialConstructor() throws {
    let plan = try plan(
      """
      enum Event {
        case invalid(name: String, callback: () -> Void)
        case valid(_ name: String, count: Int?)
      }
      """
    )
    guard case .enumeration(let cases) = plan.body,
      case .unsupported = cases[0],
      case .payload(_, let fields) = cases[1]
    else {
      Issue.record("Expected unsupported case and complete supported payload")
      return
    }
    #expect(fields.count == 2)
    #expect(fields[0].label == nil)
    #expect(fields[0].field.key.trimmedDescription == "\"_\"")
    #expect(fields[1].label?.text == "count")
    #expect(!fields[1].field.isRequired)
    #expect(fields[1].field.nullStyle == nil)
    #expect(plan.diagnostics.count == 1)
    #expect(plan.diagnostics.first?.diagMessage.severity == .error)
    let emitted = SchemaEmitter.declarations(for: plan).map { $0.formatted().description }.joined()
    #expect(!emitted.contains("Self.invalid"))
    #expect(emitted.contains("Self.valid($0, count: $1)"))
  }

  @Test func classDoesNotAssumeSynthesizedMemberwiseInitializer() throws {
    let structure = try plan("struct Example { let value: String; let count: Int = 0 }")
    let classType = try plan("final class Example { let value: String; let count: Int = 0 }")
    #expect(structure.diagnostics.count == 1)
    #expect(classType.diagnostics.isEmpty)
    #expect(classType.declaration.accessModifier == nil)
  }

  @Test func initializerComparisonNormalizesBuiltinSpellings() throws {
    let plan = try plan(
      """
      struct Example {
        let values: Swift.Optional<Swift.Array<String>>
        init(values: [String]?) {}
      }
      """
    )
    #expect(plan.diagnostics.isEmpty)
  }

  @Test(arguments: [false, true])
  func initializerOverloadMatchingIgnoresDeclarationOrder(matchingInitializerFirst: Bool) throws {
    let firstType = matchingInitializerFirst ? "Int" : "String"
    let firstValue = matchingInitializerFirst ? "value" : "Int(value) ?? 0"
    let secondType = matchingInitializerFirst ? "String" : "Int"
    let secondValue = matchingInitializerFirst ? "Int(value) ?? 0" : "value"
    let source = """
      struct Token {
        let value: Int

        init(value: \(firstType)) {
          self.value = \(firstValue)
        }

        init(value: \(secondType)) {
          self.value = \(secondValue)
        }
      }
      """
    let plan = try plan(source)
    #expect(plan.diagnostics.isEmpty)

    assertMacroExpansion(
      "@Schemable\n" + source,
      expandedSource: """
        struct Token {
          let value: Int

          init(value: \(firstType)) {
            self.value = \(firstValue)
          }

          init(value: \(secondType)) {
            self.value = \(secondValue)
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Token> {
            JSONSchema(Token.init) {
              JSONObject {
                JSONProperty(key: "value") {
                  JSONInteger()
                }
                .required()
              }
            }
          }
        }

        extension Token: Schemable {
        }
        """,
      diagnostics: [],
      macros: ["Schemable": SchemableMacro.self]
    )
  }

  @Test(arguments: [false, true])
  func initializerOverloadMatchingChecksAllParametersInOrder(
    matchingInitializerFirst: Bool
  ) throws {
    let initializers = [
      "init(count: Int, name: String) {}",
      "init(name: String, count: String) {}",
      "init(name: String, count: Int) {}",
    ]
    let orderedInitializers =
      matchingInitializerFirst ? Array(initializers.reversed()) : initializers
    let plan = try plan(
      """
      struct Example {
        let name: String
        let count: Int
        \(orderedInitializers.joined(separator: "\n"))
      }
      """
    )
    #expect(plan.diagnostics.isEmpty)
  }

  @Test(arguments: [
    ("Swift.Int", "String", "Int"),
    ("Swift.Optional<Swift.Array<String>>", "[Int]?", "[String]?"),
    ("Swift.Dictionary<String, Swift.Array<Int>>", "[String: [String]]", "[String: [Int]]"),
    ("[String: Int]?", "[String: String]?", "Swift.Optional<Swift.Dictionary<String, Int>>"),
  ])
  func initializerOverloadSelectionNormalizesBuiltinSpellings(
    propertyType: String,
    incompatibleType: String,
    compatibleType: String
  ) throws {
    let plan = try plan(
      """
      struct Example {
        let value: \(propertyType)
        init(value: \(incompatibleType)) {}
        init(value: \(compatibleType)) {}
      }
      """
    )
    #expect(plan.diagnostics.isEmpty)
  }

  @Test(arguments: [false, true], [false, true])
  func recursiveInitializerOverloadsNormalizeSelfInBothDeclarationOrders(
    matchingInitializerFirst: Bool,
    propertyUsesSelf: Bool
  ) throws {
    let propertyType = propertyUsesSelf ? "Self" : "Node"
    let parameterType = propertyUsesSelf ? "Node" : "Self"
    let firstType = matchingInitializerFirst ? parameterType : "String"
    let firstValue = matchingInitializerFirst ? "children" : "[]"
    let secondType = matchingInitializerFirst ? "String" : parameterType
    let secondValue = matchingInitializerFirst ? "[]" : "children"
    let plan = try plan(
      """
      struct Node {
        let children: [\(propertyType)]
        init(children: [\(firstType)]) { self.children = \(firstValue) }
        init(children: [\(secondType)]) { self.children = \(secondValue) }
      }
      """
    )
    #expect(plan.diagnostics.isEmpty)
  }

  @Test func initializerSelfNormalizationPreservesUnrelatedTypeMismatch() throws {
    let plan = try plan(
      """
      struct Node {
        let children: [Self]
        init(children: [OtherNode]) { self.children = [] }
      }
      """
    )
    #expect(plan.diagnostics.count == 1)
    let diagnostic = try #require(plan.diagnostics.first)
    #expect(diagnostic.diagMessage.severity == .error)
    #expect(
      diagnostic.message == """
        Parameter 'children' has type '[OtherNode]' but schema expects '[Self]'. \
        This type mismatch will cause the generated schema to fail.
        """
    )
  }

  @Test(arguments: [false, true])
  func incompatibleOverloadsPreserveFirstCandidateDiagnostic(stringInitializerFirst: Bool) throws {
    let firstType = stringInitializerFirst ? "String" : "Bool"
    let secondType = stringInitializerFirst ? "Bool" : "String"
    let plan = try plan(
      """
      struct Example {
        let value: Int
        init(value: \(firstType)) {}
        init(value: \(secondType)) {}
      }
      """
    )
    #expect(plan.diagnostics.count == 1)
    let diagnostic = try #require(plan.diagnostics.first)
    #expect(diagnostic.diagMessage.severity == .error)
    #expect(
      diagnostic.message == """
        Parameter 'value' has type '\(firstType)' but schema expects 'Int'. \
        This type mismatch will cause the generated schema to fail.
        """
    )
  }

  @Test func variableDefaultDoesNotTriggerConstantInitializerWarning() throws {
    let plan = try plan(
      """
      struct Example {
        let name: String
        var count: Int = 0
      }
      """
    )
    #expect(plan.diagnostics.isEmpty)
  }

  @Test func inferredPropertyIsNotSilentlyDropped() throws {
    let plan = try plan(
      """
      struct Example {
        let name = "example"
        @ExcludeFromSchema let ignored = 0
      }
      """
    )
    #expect(plan.diagnostics.count == 1)
    #expect(plan.diagnostics.first?.message.contains("explicit type annotation") == true)
  }

  @Test func arrayCompatibilityUsesNormalizedTypeNotSourcePrefix() throws {
    let plan = try plan(
      """
      struct Example {
        @ArrayOptions(.minItems(1))
        let values: Swift.Optional<Swift.Array<String>>
        @ArrayOptions(.minItems(1))
        let dictionary: [String: String]
        @NumberOptions(.minimum(0))
        let number: Float
      }
      """
    )
    #expect(plan.diagnostics.count == 1)
    #expect(plan.diagnostics.first?.message.contains("dictionary") == true)
  }

  @Test func invalidOptionSyntaxIsDiagnosed() throws {
    let plan = try plan(
      """
      struct Example {
        @SchemaOptions(savedOptions)
        let name: String
      }
      """
    )
    #expect(plan.diagnostics.count == 1)
    #expect(plan.diagnostics.first?.diagMessage.severity == .error)
  }

  @Test(arguments: ["optionalNulls: flag", "enumComposition: composition"])
  func nonliteralConfigurationIsDiagnosed(arguments: String) {
    #expect(throws: DiagnosticsError.self) {
      try MacroConfiguration(attribute: AttributeSyntax("@Schemable(\(raw: arguments))"))
    }
  }

  @Test func modifierEmitterPreservesAllArgumentsAndClosureSignature() throws {
    let source: ExprSyntax = ".custom(first: 1, second: 2)"
    let modifier = try #require(ParsedOption(source))
    let result = SchemaOptionsGenerator.apply([modifier], to: "JSONString()")
    #expect(result.trimmedDescription.contains(".custom(first: 1, second: 2)"))

    let closure: ExprSyntax = ".custom { value in value }"
    let closureModifier = try #require(ParsedOption(closure))
    let closureResult = SchemaOptionsGenerator.apply([closureModifier], to: "JSONString()")
    #expect(closureResult.trimmedDescription.contains("{ value in value }"))
  }
}
