import CustomDump
import Foundation
import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
private struct ScalarMacroNames: Equatable {
  @SchemaOptions(.key("é"))
  let first: Int
  @SchemaOptions(.key("é"))
  let second: String
}

@Schemable
private struct ScalarMacroDictionary {
  let data: [String: Int]
}

@Schemable
private struct ScalarNamedFirst {
  static var schemaDefinitionName: String { "\u{e9}" }
  let value: Int
}

@Schemable
private struct ScalarNamedSecond {
  static var schemaDefinitionName: String { "e\u{301}" }
  let value: String
}

struct ScalarKeyIntegrationTests {
  @Test func explicitPropertiesAndCompiledMacroRetainBothNames() throws {
    let input = try JSONValue.parse(#"{"\u00e9":1,"e\u0301":"two"}"#)
    let component = JSONObject {
      JSONProperty(key: "\u{e9}") { JSONInteger() }.required()
      JSONProperty(key: "e\u{301}") { JSONString() }.required()
    }
    let output = try #require(component.parse(input).value)
    #expect(output.0 == 1)
    #expect(output.1 == "two")
    #expect(component.schemaValue["properties"]?.object?.count == 2)
    #expect(component.definition().validate(input).isValid)
    expectNoDifference(
      ScalarMacroNames.schema.parse(input).value,
      ScalarMacroNames(first: 1, second: "two")
    )
    #expect(ScalarMacroNames.schema.definition().validate(input).isValid)
  }

  @Test func additionalAndPatternOutputsRemainScalarKeyed() throws {
    let input = try JSONValue.parse(#"{"\u00e9":1,"e\u0301":2}"#)
    let additional = JSONObject()
      .additionalProperties { JSONInteger() }
      .map { $0.1.matches }
    let output = try #require(additional.parse(input).value)
    #expect(output.count == 2)
    #expect(output["\u{e9}"] == 1)
    #expect(output["e\u{301}"] == 2)
    let patterns = JSONObject()
      .patternProperties { JSONProperty(key: ".*") { JSONInteger() }.required() }
    let matches = try #require(patterns.parse(input).value?.1.matches)
    #expect(matches.count == 2)
    #expect(matches["\u{e9}"]?.value == 1)
    #expect(matches["e\u{301}"]?.value == 2)
    let exported = additional.stringKeyedDictionary().parse(input)
    guard case .keyConversionFailed(.canonicalCollision) = exported.errors?.first else {
      Issue.record("Strict typed export must report a canonical key collision")
      return
    }
    #expect(additional.stringKeyedDictionary().parse(["ordinary": 1]).value == ["ordinary": 1])
  }

  @Test func compiledStringDictionaryMacroRejectsCollisions() throws {
    let input = try JSONValue.parse(#"{"data":{"\u00e9":1,"e\u0301":2}}"#)
    let result = ScalarMacroDictionary.schema.parse(input)
    #expect(result.value == nil)
    guard case .keyConversionFailed(.canonicalCollision) = result.errors?.first else {
      Issue.record("Generated String dictionary conversion must reject, not discard, a name")
      return
    }
    #expect(
      ScalarMacroDictionary.schema.parse(["data": ["ordinary": 1]]).value?.data == ["ordinary": 1]
    )
  }

  @Test func documentDefinitionsAndReferencesRetainBothNames() throws {
    let document = try SchemaDocument {
      JSONObject {
        JSONProperty(key: "first") { JSONReusable(ScalarNamedFirst.self) }.required()
        JSONProperty(key: "second") { JSONReusable(ScalarNamedSecond.self) }.required()
      }
    }
    #expect(document.schemaValue["$defs"]?.object?.count == 2)
    let input: JSONValue = ["first": ["value": 1], "second": ["value": "two"]]
    let output = try #require(document.parse(input).value)
    #expect(output.0.value == 1)
    #expect(output.1.value == "two")
    #expect(document.definition().validate(input).isValid)
    #expect(
      !document.definition().validate(["first": ["value": "wrong"], "second": ["value": 2]]).isValid
    )
  }

  @Test func nestedCodableCollisionHasPathAndUnderlyingCause() throws {
    let collision = try JSONValue.parse(#"{"\u00e9":1,"e\u0301":2}"#)
    do {
      _ = try JSONEncoder().encode(JSONValue.object(["outer": collision]))
      Issue.record("Expected a strict object-key encoding failure")
    } catch EncodingError.invalidValue(_, let context) {
      expectNoDifference(context.codingPath.map(\.stringValue), ["outer"])
      #expect(context.underlyingError is JSONKeyConversionError)
    }
    #expect(try JSONValue.parse(collision.serialized()) == collision)
  }
}
