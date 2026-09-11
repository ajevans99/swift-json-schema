import SwiftSyntax
import SwiftSyntaxBuilder
import Testing

@testable import JSONSchemaMacro

struct TypeAnalysisTests {
  private func parse(_ source: String) throws -> SchemaType {
    try SchemaType.parse(TypeSyntax(stringLiteral: source)).get()
  }

  @Test func codingKeysDecodeLiteralsAndPreserveBacktickedNames() throws {
    let declaration: DeclSyntax = ##"""
      struct Example {
        enum CodingKeys: String {
          case `default`
          case `repeat` = "escaped\nvalue"
          case raw = #"raw\nvalue"#
          case unicode = "\u{1F30D}"
        }
      }
      """##
    let members = try #require(declaration.as(StructDeclSyntax.self)?.memberBlock.members)
    let mapping = try #require(members.extractCodingKeys())
    #expect(mapping["default"] == "default")
    #expect(mapping["repeat"] == "escaped\nvalue")
    #expect(mapping["raw"] == #"raw\nvalue"#)
    #expect(mapping["unicode"] == "🌍")
  }

  @Test(arguments: ["String?", "String!", "Optional<String>", "Swift.Optional<Swift.String>"])
  func optionalSpellings(source: String) throws {
    let type = try parse(source)
    guard case .optional(.scalar(.string)) = type else {
      Issue.record("Expected an optional string for \(source)")
      return
    }
    #expect(type.isOptional)
    #expect(type.isScalar)
    #expect(type.isPrimitive)
  }

  @Test(arguments: ["[Int]", "Array<Int>", "Swift.Array<Swift.Int>"])
  func arraySpellings(source: String) throws {
    let type = try parse(source)
    guard case .array(.scalar(.int)) = type else {
      Issue.record("Expected an integer array for \(source)")
      return
    }
    #expect(!type.isOptional)
    #expect(!type.isScalar)
    #expect(type.isPrimitive)
  }

  @Test(arguments: [
    "[String: Bool]",
    "Dictionary<String, Bool>",
    "Swift.Dictionary<Swift.String, Swift.Bool>",
  ])
  func dictionarySpellings(source: String) throws {
    let type = try parse(source)
    guard case .dictionary(key: .scalar(.string), value: .scalar(.bool)) = type else {
      Issue.record("Expected a string-to-boolean dictionary for \(source)")
      return
    }
    #expect(!type.isScalar)
    #expect(type.isPrimitive)
  }

  @Test(arguments: SupportedPrimitive.allCases.filter(\.isScalar))
  func scalarSpellings(primitive: SupportedPrimitive) throws {
    for source in [primitive.rawValue, "Swift.\(primitive.rawValue)"] {
      let type = try parse(source)
      guard case .scalar(let parsed) = type else {
        Issue.record("Expected a scalar for \(source)")
        return
      }
      #expect(parsed == primitive)
      #expect(type.isScalar)
      #expect(type.isPrimitive)
      #expect(!type.isOptional)
      #expect(
        TypeSchemaEmitter.expression(for: type).trimmedDescription == "\(primitive.schema)()"
      )
    }
  }

  @Test func nestedCollectionsAndOptionals() throws {
    let type = try parse("Swift.Optional<Swift.Array<Dictionary<String?, Optional<[Double!]>>>>")
    guard
      case .optional(
        .array(
          .dictionary(
            key: .optional(.scalar(.string)),
            value: .optional(.array(.optional(.scalar(.double))))
          )
        )
      ) = type
    else {
      Issue.record("Expected normalized nested collections")
      return
    }
    #expect(type.isOptional)
    #expect(type.isPrimitive)
    #expect(!type.isScalar)
    #expect(!type.usesSelfReference)
  }

  @Test(arguments: [
    "Box<String>",
    "Box<(Int, Int)>",
    "Module.Box<Swift.Optional<Node>>",
    "Outer<Int>.Inner<String>",
    "Outer.`default`",
    "Other.Array<Int>",
    "Outer.Swift.Dictionary<String, Int>",
  ])
  func namedTypesPreserveTheirFullSyntax(source: String) throws {
    let syntax = TypeSyntax(stringLiteral: source)
    let type = try SchemaType.parse(syntax).get()
    guard case .named(let named) = type else {
      Issue.record("Expected a named type for \(source)")
      return
    }
    #expect(named.id == syntax.id)
    #expect(named.trimmedDescription == source)
    #expect(!type.isOptional)
    #expect(!type.isPrimitive)
    #expect(!type.isScalar)
    #expect(TypeSchemaEmitter.expression(for: type).trimmedDescription == "\(source).schema")
  }

  @Test(arguments: ["[Key: String]", "[Key?: String]", "[String?: Key]"])
  func dictionaryKeySupport(source: String) throws {
    guard case .dictionary = try parse(source) else {
      Issue.record("Expected a supported dictionary for \(source)")
      return
    }
  }

  @Test(arguments: [
    "() -> Void",
    "(Int, String)",
    "String.Type",
    "any First & Second",
    "@Sendable () -> Void",
    "[Int: String]",
    "[Bool?: String]",
    "[[String]: String]",
    "[[String: String]: String]",
    "[String: () -> Void]",
    "Array",
    "Optional",
    "Dictionary",
    "Array<>",
    "Array<Int, String>",
    "Optional<Int, String>",
    "Dictionary<String>",
    "Dictionary<String, Int, Bool>",
    "Swift.Array<>",
    "Swift.Optional<Int, String>",
    "Swift.Dictionary<String>",
    "Swift.Dictionary<String, Int, Bool>",
    "String<Int>",
  ])
  func unsupportedTypesRetainTheirSyntax(source: String) {
    let syntax = TypeSyntax(stringLiteral: source)
    guard case .failure(let error) = SchemaType.parse(syntax) else {
      Issue.record("Expected unsupported type \(source)")
      return
    }
    #expect(error.syntax.id == syntax.id)
    #expect(error.syntax.trimmedDescription == syntax.trimmedDescription)
  }

  @Test func missingTypeFails() {
    let syntax = TypeSyntax(MissingTypeSyntax(placeholder: .identifier("", presence: .missing)))
    guard case .failure(let error) = SchemaType.parse(syntax) else {
      Issue.record("Expected a missing type to fail")
      return
    }
    #expect(error.syntax.id == syntax.id)
  }

  @Test(arguments: [
    "Node",
    "Self",
    "Node?",
    "Self!",
    "Array<Node>",
    "Swift.Optional<Swift.Array<Self>>",
    "[String: Node]",
    "[Node?: String]",
  ])
  func recursiveTypeInventory(source: String) throws {
    let parsed = try parse(source)
    #expect(!parsed.usesSelfReference)
    let resolved = parsed.resolvingSelfReferences(named: "Node")
    #expect(resolved.usesSelfReference)
    #expect(resolved.resolvingSelfReferences(named: "Unrelated").usesSelfReference)
  }

  @Test func recursiveResolutionPreservesStructure() throws {
    let resolved = try parse("Optional<[Node?: [String: Self]]>")
      .resolvingSelfReferences(named: "Node")
    guard
      case .optional(
        .dictionary(
          key: .optional(.selfReference),
          value: .dictionary(key: .scalar(.string), value: .selfReference)
        )
      ) = resolved
    else {
      Issue.record("Expected self references in nested dictionary keys and values")
      return
    }
  }

  @Test(arguments: [
    "Box<Node>",
    "Box<Self>",
    "Module.Box<Node>",
    "Node.Child",
    "Self.Child",
    "Module.Node",
    "Node<String>",
    "[String: Box<Node>]",
  ])
  func genericArgumentsAndPartialNamesAreNotSelfReferences(source: String) throws {
    let resolved = try parse(source).resolvingSelfReferences(named: "Node")
    #expect(!resolved.usesSelfReference)
  }

  @Test func exactQualifiedAndBacktickedSelfReferences() throws {
    let resolved = try parse("Outer.`Node`").resolvingSelfReferences(named: "`Outer`.Node")
    guard case .selfReference = resolved else {
      Issue.record("Expected an exact sanitized qualified name to resolve")
      return
    }
    #expect(!resolved.isScalar)
    #expect(!resolved.isPrimitive)
    #expect(
      TypeSchemaEmitter.expression(for: resolved).trimmedDescription
        == "JSONDynamicReference<Self>()"
    )
  }

  @Test func arrayAndStringDictionaryEmission() throws {
    let type = try parse("Swift.Dictionary<Swift.String?, Array<Float?>>")
    let expected: ExprSyntax = """
      JSONObject()
      .additionalProperties {
        JSONArray {
          JSONNumber()
        }
      }
      .map(\\.1)
      .map(\\.matches)
      """
    #expect(
      TypeSchemaEmitter.expression(for: type).tokens(viewMode: .sourceAccurate).map(\.text)
        == expected.tokens(viewMode: .sourceAccurate).map(\.text)
    )
  }

  @Test func namedDictionaryKeyReconstructionEmission() throws {
    let type = try parse("[Module.Key<String>?: Node?]").resolvingSelfReferences(named: "Node")
    let expected: ExprSyntax = """
      JSONObject()
      .propertyNames { Module.Key<String>.schema }
      .additionalProperties {
        JSONDynamicReference<Self>()
      }
      .map { value in
        let (_, capturedNames) = value.0
        let additionalProperties = value.1
        return Dictionary(
          uniqueKeysWithValues: zip(capturedNames.seen, capturedNames.raw)
            .compactMap { parsedKey, rawKey in
              additionalProperties.matches[rawKey].map { parsedValue in
                (parsedKey, parsedValue)
              }
            }
        )
      }
      """
    #expect(
      TypeSchemaEmitter.expression(for: type).tokens(viewMode: .sourceAccurate).map(\.text)
        == expected.tokens(viewMode: .sourceAccurate).map(\.text)
    )
  }
}
