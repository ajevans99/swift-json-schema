import JSONSchema
import JSONSchemaBuilder
import Testing

/// Tests for the .orNull() modifier
struct OrNullModifierTests {

  // MARK: - Schema generation tests

  @Test func typeStyleWithInteger() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONInteger()
        .orNull(style: .type)
    }

    let expected: [String: JSONValue] = [
      "type": ["integer", "null"]
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func typeStyleWithString() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONString()
        .orNull(style: .type)
    }

    let expected: [String: JSONValue] = [
      "type": ["string", "null"]
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func typeStyleWithNumber() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONNumber()
        .orNull(style: .type)
    }

    let expected: [String: JSONValue] = [
      "type": ["number", "null"]
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func typeStyleWithBoolean() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONBoolean()
        .orNull(style: .type)
    }

    let expected: [String: JSONValue] = [
      "type": ["boolean", "null"]
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func unionStyleWithInteger() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONInteger()
        .orNull(style: .union)
    }

    let expected: [String: JSONValue] = [
      "oneOf": [
        ["type": "integer"],
        ["type": "null"],
      ]
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func unionStyleWithString() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONString()
        .orNull(style: .union)
    }

    let expected: [String: JSONValue] = [
      "oneOf": [
        ["type": "string"],
        ["type": "null"],
      ]
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func unionStyleWithArray() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONArray {
        JSONString()
      }
      .orNull(style: .union)
    }

    let expected: [String: JSONValue] = [
      "oneOf": [
        [
          "type": "array",
          "items": ["type": "string"],
        ],
        ["type": "null"],
      ]
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func unionStyleWithObject() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONObject {
        JSONProperty(key: "name") {
          JSONString()
        }
      }
      .orNull(style: .union)
    }

    let expected: [String: JSONValue] = [
      "oneOf": [
        [
          "type": "object",
          "properties": [
            "name": ["type": "string"]
          ],
        ],
        ["type": "null"],
      ]
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func unionAnyOfStyleWithObject() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONObject {
        JSONProperty(key: "name") {
          JSONString()
        }
      }
      .orNull(style: .unionAnyOf)
    }

    let expected: [String: JSONValue] = [
      "anyOf": [
        [
          "type": "object",
          "properties": [
            "name": ["type": "string"]
          ],
        ],
        ["type": "null"],
      ]
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  // MARK: - Modifier chaining tests

  @Test func typeStyleWithOtherModifiers() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONInteger()
        .orNull(style: .type)
        .title("Age")
        .description("User's age in years")
    }

    let expected: [String: JSONValue] = [
      "type": ["integer", "null"],
      "title": "Age",
      "description": "User's age in years",
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func unionStyleWithOtherModifiers() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONString()
        .orNull(style: .union)
        .title("Name")
        .description("User's name")
    }

    let expected: [String: JSONValue] = [
      "oneOf": [
        ["type": "string"],
        ["type": "null"],
      ],
      "title": "Name",
      "description": "User's name",
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func unionAnyOfStyleWithOtherModifiers() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONString()
        .orNull(style: .unionAnyOf)
        .title("Alias")
    }

    let expected: [String: JSONValue] = [
      "anyOf": [
        ["type": "string"],
        ["type": "null"],
      ],
      "title": "Alias",
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func typeStyleWithConstraints() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONInteger()
        .minimum(0)
        .maximum(100)
        .orNull(style: .type)
    }

    let expected: [String: JSONValue] = [
      "type": ["integer", "null"],
      "minimum": 0,
      "maximum": 100,
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  // MARK: - Parsing tests

  @Test func typeStyleParseNull() throws {
    let schema = JSONInteger()
      .orNull(style: .type)

    let result = schema.parse(.null)

    #expect(result.value != nil)  // result.value is Int?? - the outer optional is some(.none)
    #expect(result.value! == nil)  // The inner optional (Int?) is nil
    #expect(result.errors == nil)
  }

  @Test func typeStyleParseValidValue() throws {
    let schema = JSONInteger()
      .orNull(style: .type)

    let result = schema.parse(.integer(42))

    #expect(result.value == 42)
    #expect(result.errors == nil)
  }

  @Test func typeStyleParseInvalidValue() throws {
    let schema = JSONInteger()
      .orNull(style: .type)

    let result = schema.parse(.string("not an integer"))

    #expect(result.value == nil)
    #expect(result.errors != nil)
  }

  @Test func unionStyleParseNull() throws {
    let schema = JSONInteger()
      .orNull(style: .union)

    let result = schema.parse(.null)

    #expect(result.value != nil)  // result.value is Int?? - the outer optional is some(.none)
    #expect(result.value! == nil)  // The inner optional (Int?) is nil
    #expect(result.errors == nil)
  }

  @Test func unionStyleParseValidValue() throws {
    let schema = JSONInteger()
      .orNull(style: .union)

    let result = schema.parse(.integer(42))

    #expect(result.value == 42)
    #expect(result.errors == nil)
  }

  @Test func unionStyleParseInvalidValue() throws {
    let schema = JSONInteger()
      .orNull(style: .union)

    let result = schema.parse(.string("not an integer"))

    #expect(result.value == nil)
    #expect(result.errors != nil)
  }

  @Test func typeStyleStringParseNull() throws {
    let schema = JSONString()
      .orNull(style: .type)

    let result = schema.parse(.null)

    #expect(result.value != nil)  // result.value is String?? - the outer optional is some(.none)
    #expect(result.value! == nil)  // The inner optional (String?) is nil
    #expect(result.errors == nil)
  }

  @Test func typeStyleStringParseValidValue() throws {
    let schema = JSONString()
      .orNull(style: .type)

    let result = schema.parse(.string("hello"))

    #expect(result.value == "hello")
    #expect(result.errors == nil)
  }

  @Test func typeStyleNumberParseNull() throws {
    let schema = JSONNumber()
      .orNull(style: .type)

    let result = schema.parse(.null)

    #expect(result.value != nil)  // result.value is Double?? - the outer optional is some(.none)
    #expect(result.value! == nil)  // The inner optional (Double?) is nil
    #expect(result.errors == nil)
  }

  @Test func typeStyleNumberParseValidValue() throws {
    let schema = JSONNumber()
      .orNull(style: .type)

    let result = schema.parse(.number(3.14))

    #expect(result.value == 3.14)
    #expect(result.errors == nil)
  }

  @Test func typeStyleBooleanParseNull() throws {
    let schema = JSONBoolean()
      .orNull(style: .type)

    let result = schema.parse(.null)

    #expect(result.value != nil)  // result.value is Bool?? - the outer optional is some(.none)
    #expect(result.value! == nil)  // The inner optional (Bool?) is nil
    #expect(result.errors == nil)
  }

  @Test func typeStyleBooleanParseValidValue() throws {
    let schema = JSONBoolean()
      .orNull(style: .type)

    let result = schema.parse(.boolean(true))

    #expect(result.value == true)
    #expect(result.errors == nil)
  }

  @Test func unionStyleArrayParseNull() throws {
    let schema = JSONArray {
      JSONString()
    }
    .orNull(style: .union)

    let result = schema.parse(.null)

    #expect(result.value != nil)  // result.value is [String]?? - the outer optional is some(.none)
    #expect(result.value! == nil)  // The inner optional ([String]?) is nil
    #expect(result.errors == nil)
  }

  @Test func unionStyleArrayParseValidValue() throws {
    let schema = JSONArray {
      JSONString()
    }
    .orNull(style: .union)

    let result = schema.parse(.array([.string("a"), .string("b")]))

    #expect(result.value == ["a", "b"])
    #expect(result.errors == nil)
  }

  @Test func unionStyleArrayParseEmptyArray() throws {
    let schema = JSONArray {
      JSONString()
    }
    .orNull(style: .union)

    let result = schema.parse(.array([]))

    #expect(result.value == [])
    #expect(result.errors == nil)
  }

  // MARK: - Complex scenarios

  @Test func typeStyleWithDefaultValue() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONInteger()
        .orNull(style: .type)
        .default(nil)
    }

    let expected: [String: JSONValue] = [
      "type": ["integer", "null"],
      "default": .null,
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func typeStyleWithExamples() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONInteger()
        .orNull(style: .type)
        .examples([.number(42), .null, .number(100)])
    }

    let expected: [String: JSONValue] = [
      "type": ["integer", "null"],
      "examples": [42, .null, 100],
    ]

    #expect(schema.schemaValue == .object(expected))
  }

  @Test func multipleNullsInTypeArrayPreventsDuplicates() {
    @JSONSchemaBuilder var schema: some JSONSchemaComponent {
      JSONInteger()
        .orNull(style: .type)
        .orNull(style: .type)
    }

    let expected: [String: JSONValue] = [
      "type": ["integer", "null"]
    ]

    #expect(schema.schemaValue == .object(expected))
  }
}
