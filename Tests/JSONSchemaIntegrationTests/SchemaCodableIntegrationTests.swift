import Foundation
import JSONSchema
import JSONSchemaBuilder
import JSONSchemaConversion
import Testing

struct SchemaCodableIntegrationTests {
  @Test
  func decodeBooleanSchema() throws {
    let json = "true"
    let decoder = JSONDecoder()
    let schema = try decoder.decode(Schema.self, from: Data(json.utf8))

    let expected = try Schema(rawSchema: .boolean(true), context: Context(dialect: .draft2020_12))
    #expect(schema == expected)

  }

  @Test
  func decodeObjectSchema() throws {
    let json = """
      {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "age": { "type": "integer", "minimum": 0 }
        },
        "required": ["name"]
      }
      """
    let decoder = JSONDecoder()
    let schema = try decoder.decode(Schema.self, from: Data(json.utf8))

    let expected: JSONValue = [
      "type": "object",
      "properties": [
        "name": ["type": "string"],
        "age": ["type": "integer", "minimum": 0],
      ],
      "required": ["name"],
    ]
    let expectedSchema = try Schema(rawSchema: expected, context: Context(dialect: .draft2020_12))
    #expect(schema == expectedSchema)

  }

  @Test(arguments: [JSONValue.integer(2), .integer(0), .string("two")])
  func decodedLocalReferencesValidateLikeRawSchema(value: JSONValue) throws {
    let json = """
      {
        "$defs": { "positiveInteger": { "type": "integer", "minimum": 1 } },
        "type": "object",
        "properties": { "value": { "$ref": "#/$defs/positiveInteger" } },
        "required": ["value"]
      }
      """
    let decoded = try JSONDecoder().decode(Schema.self, from: Data(json.utf8))
    let direct = try Schema(
      rawSchema: JSONDecoder().decode(JSONValue.self, from: Data(json.utf8)),
      context: Context(dialect: .draft2020_12)
    )
    let instance: JSONValue = ["value": value]
    let expected = direct.validate(instance)
    let actual = decoded.validate(instance)

    #expect(expected.isValid == (value == .integer(2)))
    #expect(actual.isValid == expected.isValid)
    #expect(actual.jsonValue == expected.jsonValue)
    if !expected.isValid {
      let keyword = value == .integer(0) ? "minimum" : "type"
      let error = try #require(
        leafErrors(expected.errors ?? []).first { $0.keyword == keyword }
      )
      #expect(error.keywordLocation.description == "#/properties/value/$ref/\(keyword)")
      #expect(error.instanceLocation.description == "#/value")
    }
  }

  @Test(arguments: [true, false])
  func decodedSchemaSupportsMetaSchemaValidation(validSchema: Bool) throws {
    let json = validSchema ? #"{"type":"integer","minimum":1}"# : #"{"type":123}"#
    let direct = try Schema(
      rawSchema: JSONDecoder().decode(JSONValue.self, from: Data(json.utf8)),
      context: Context(dialect: .draft2020_12)
    )
    let expected = try direct.validateAgainstMetaSchema()
    #expect(expected.isValid == validSchema)
    if !validSchema {
      #expect(
        leafErrors(expected.errors ?? [])
          .contains {
            $0.instanceLocation.description == "#/type"
          }
      )
    }

    let decoded = try JSONDecoder().decode(Schema.self, from: Data(json.utf8))
    let actual = try decoded.validateAgainstMetaSchema()
    #expect(
      try metaSchemaOutputSortingPropertyNames(actual)
        == metaSchemaOutputSortingPropertyNames(expected)
    )
  }

  @Test func falseSchemaRoundTripStillRejectsInstances() throws {
    let direct = try Schema(rawSchema: false, context: Context(dialect: .draft2020_12))
    let encoded = try JSONEncoder().encode(direct)
    #expect(try JSONDecoder().decode(JSONValue.self, from: encoded) == .boolean(false))
    let decoded = try JSONDecoder().decode(Schema.self, from: encoded)
    let reencoded = try JSONEncoder().encode(decoded)
    #expect(try JSONDecoder().decode(JSONValue.self, from: reencoded) == .boolean(false))

    for instance: JSONValue in [.null, 1, "value", [], ["key": true]] {
      let result = decoded.validate(instance)
      #expect(!result.isValid)
      #expect(result.jsonValue == direct.validate(instance).jsonValue)
      let error = try #require(result.errors?.first)
      #expect(error.keyword == "boolean")
      #expect(error.keywordLocation.description == "#")
      #expect(error.instanceLocation.description == "#")
    }
  }

  @Test(
    arguments: [
      "null", "42", #""not a schema""#, "[]",
      #"{"$vocabulary":"invalid"}"#,
      #"{"$vocabulary":{"https://example.com/unsupported":true}}"#,
    ],
    [false, true]
  )
  func decodingFailurePreservesCodingPath(json: String, nested: Bool) throws {
    let data = Data((nested ? #"{"schemas":[\#(json)]}"# : json).utf8)
    do {
      if nested {
        _ = try JSONDecoder().decode(SchemaEnvelope.self, from: data)
      } else {
        _ = try JSONDecoder().decode(Schema.self, from: data)
      }
      Issue.record("Expected schema decoding to fail")
    } catch DecodingError.dataCorrupted(let context) {
      #expect(context.codingPath.map(\.stringValue) == (nested ? ["schemas", "Index 0"] : []))
      #expect(context.codingPath.last?.intValue == (nested ? 0 : nil))
      #expect(
        context.debugDescription
          == "Expected either a boolean or an object representing a schema."
      )
    }
  }

  @Test(arguments: [true, false])
  func decodedBooleanSupportsMetaSchemaValidation(value: Bool) throws {
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(Schema.self, from: data)
    let direct = try Schema(rawSchema: .boolean(value), context: .init(dialect: .draft2020_12))
    let result = try decoded.validateAgainstMetaSchema()

    #expect(result.isValid)
    #expect(result.jsonValue == (try direct.validateAgainstMetaSchema()).jsonValue)
  }

  @Test func decodedObjectPreservesSupportedKeywordsAndNulls() throws {
    let json = """
      {
        "type": "object",
        "default": null,
        "unknownKeyword": {"type": 123},
        "properties": {"value": {"type": "integer", "custom": true}}
      }
      """
    let decoded = try JSONDecoder().decode(Schema.self, from: Data(json.utf8))
    let encoded = try JSONEncoder().encode(decoded)
    let expected: JSONValue = [
      "type": "object",
      "default": .null,
      "properties": ["value": ["type": "integer", "custom": true]],
    ]
    #expect(decoded.jsonValue == expected)
    #expect(try JSONDecoder().decode(JSONValue.self, from: encoded) == expected)
  }

  @Test func decodedMetaSchemaValidationRetainsInactiveKeywords() throws {
    let json = """
      {
        "$vocabulary": {"https://json-schema.org/draft/2020-12/vocab/core": true},
        "type": 123
      }
      """
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(Schema.self, from: data)
    let direct = try Schema(
      rawSchema: JSONDecoder().decode(JSONValue.self, from: data),
      context: .init(dialect: .draft2020_12)
    )
    #expect(decoded.jsonValue.object?["type"] == nil)
    let result = try decoded.validateAgainstMetaSchema()
    #expect(!result.isValid)
    #expect(
      try metaSchemaOutputSortingPropertyNames(result)
        == metaSchemaOutputSortingPropertyNames(direct.validateAgainstMetaSchema())
    )
    #expect(
      leafErrors(result.errors ?? []).contains { $0.instanceLocation.description == "#/type" }
    )
  }

  @Test func decodedReferenceToFalseSchemaRejectsInstances() throws {
    let json = ##"{"$defs":{"never":false},"$ref":"#/$defs/never"}"##
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(Schema.self, from: data)
    let direct = try Schema(
      rawSchema: JSONDecoder().decode(JSONValue.self, from: data),
      context: .init(dialect: .draft2020_12)
    )
    let result = decoded.validate(.null)
    #expect(!result.isValid)
    #expect(result.jsonValue == direct.validate(.null).jsonValue)
    let error = try #require(leafErrors(result.errors ?? []).first)
    #expect(error.keyword == "boolean")
    #expect(error.keywordLocation.description == "#/$ref")
    #expect(error.instanceLocation.description == "#")
  }

  @Test(arguments: [JSONValue.integer(2), .string("two")])
  func decodedRelativeReferenceAndAnchorUseRootDocument(value: JSONValue) throws {
    let json = """
      {
        "$id": "https://example.com/root.json",
        "$defs": {
          "child": {"$id": "child.json", "$anchor": "value", "type": "integer"}
        },
        "$ref": "child.json#value"
      }
      """
    let data = Data(json.utf8)
    let decoded = try JSONDecoder().decode(Schema.self, from: data)
    let direct = try Schema(
      rawSchema: JSONDecoder().decode(JSONValue.self, from: data),
      context: .init(dialect: .draft2020_12)
    )
    let expected = direct.validate(value)
    #expect(expected.isValid == (value == .integer(2)))
    #expect(decoded.validate(value).jsonValue == expected.jsonValue)
  }

  private struct SchemaEnvelope: Decodable {
    let schemas: [Schema]
  }

  private func metaSchemaOutputSortingPropertyNames(_ result: ValidationResult) throws -> JSONValue
  {
    var output = try #require(result.jsonValue.object)
    var annotations = try #require(output["annotations"]?.array)
    let index = try #require(
      result.annotations?
        .firstIndex {
          $0.keyword == "properties"
            && $0.schemaLocation.description == "#/properties"
            && $0.instanceLocation.description == "#"
        }
    )
    var annotation = try #require(annotations[index].object)
    let names = try #require(annotation["annotation"]?.array).map { try #require($0.string) }
    // Only this annotation is a set of property names; JSONDecoder does not promise key order.
    // Preserve duplicates and all other output, including order-sensitive annotation arrays.
    annotation["annotation"] = .array(names.sorted().map(JSONValue.string))
    annotations[index] = .object(annotation)
    output["annotations"] = .array(annotations)
    return .object(output)
  }

  private func leafErrors(_ errors: [ValidationError]) -> [ValidationError] {
    errors.flatMap { error in
      guard let children = error.errors, !children.isEmpty else { return [error] }
      return leafErrors(children)
    }
  }
}

struct IPAddress: Schemable {
  static var schema: some JSONSchemaComponent<String> {
    JSONString()
      .format("ipv4")
  }
}

@Schemable
struct User {
  @SchemaOptions(.customSchema(Conversions.uuid))
  let id: UUID

  @SchemaOptions(.customSchema(Conversions.dateTime))
  let createdAt: Date

  @SchemaOptions(.customSchema(Conversions.url))
  let website: URL

  @SchemaOptions(.customSchema(IPAddress.self))
  let ipAddress: String
}

struct CustomSchemaIntegrationTests {
  @Test func parseValidInstance() throws {
    let json = """
      {"id":"123e4567-e89b-12d3-a456-426614174000","createdAt":"2025-06-27T12:34:56.789Z","website":"https://example.com","ipAddress":"192.168.0.1"}
      """
    let result = try User.schema.parse(instance: json)
    #expect(result.value != nil)
    #expect(result.errors == nil)
  }

  @Test func parseInvalidInstance() throws {
    let json = """
      {"id":"not-a-uuid","createdAt":"not-a-date","website":"not-a-url","ipAddress":"256.256.256.256"}
      """
    let result = try User.schema.parse(instance: json)
    #expect(result.value == nil)
    #expect(result.errors != nil)
  }
}
