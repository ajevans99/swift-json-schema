import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct JSONSchemaOptionBuilderTests {
  @Test func objectOptions() throws {
    @JSONSchemaBuilder var sample:
      some JSONSchemaComponent<
        (
          ((String?, String, Bool?, Double), PatternPropertiesParseResult<String?>),
          AdditionalPropertiesParseResult<Bool>
        )
      >
    {
      JSONObject {
        JSONProperty(key: "property0") { JSONString() }
        JSONProperty(key: "property1") { JSONString() }.required()
        JSONProperty(key: "property2") { JSONBoolean() }
        JSONProperty(key: "property3") { JSONNumber() }.required()
      }
      .patternProperties { JSONProperty(key: "^property[0-1]$") { JSONString() } }
      .unevaluatedProperties { false }
//      .propertyNames { JSONString().pattern("^property[0-9]$") }
      .minProperties(1)
      .maxProperties(10)
      .additionalProperties { JSONBoolean() }
    }

    let expected: [String: JSONValue] = [
      "properties": [
        "property0": [
          "type": "string"
        ],
        "property1": [
          "type": "string"
        ],
        "property2": [
          "type": "boolean"
        ],
        "property3": [
          "type": "number"
        ],
      ],
      "additionalProperties": [
        "type": "boolean"
      ],
      "patternProperties": [
        "^property[0-1]$": [
          "type": "string"
        ]
      ],
      "type": "object",
      "required": ["property1", "property3"],
      "minProperties": 1,
      "maxProperties": 10,
      "propertyNames": [
        "type": "string",
        "pattern": "^property[0-9]$",
      ],
      "unevaluatedProperties": false,
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func objectOptionsProperty() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent<(Int?, Double?)> {
      JSONObject {
        JSONProperty(key: "key1", value: JSONInteger())
        JSONProperty(key: "key2") { JSONNumber() }
      }
    }

    let expected: [String: JSONValue] = [
      "type": "object",
      "properties": [
        "key1": [
          "type": "integer"
        ],
        "key2": [
          "type": "number"
        ],
      ],
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func supplementalObjectOptions() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONObject()
        .unevaluatedProperties { JSONInteger() }
        .additionalProperties { false }
    }

    let expected: [String: JSONValue] = [
      "type": "object",
      "additionalProperties": false,
      "unevaluatedProperties": [
        "type": "integer"
      ],
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func stringOptions() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent<String> {
      JSONString()
        .minLength(12)
        .maxLength(36)
        .pattern("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        .format("uuid")
    }

    let expected: [String: JSONValue] = [
      "type": "string",
      "minLength": 12,
      "maxLength": 36,
      "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
      "format": "uuid",
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func numberOptions() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent<Int> {
      JSONInteger()
        .multipleOf(2)
        .minimum(1)
        .exclusiveMaximum(100)
    }

    let expected: [String: JSONValue] = [
      "type": "integer",
      "multipleOf": 2,
      "minimum": 1,
      "exclusiveMaximum": 100,
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func supplementalNumberOptions() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent<Double> {
      JSONNumber()
        .multipleOf(1)
        .exclusiveMinimum(0.99)
        .maximum(5000)
    }

    let expected: [String: JSONValue] = [
      "type": "number",
      "multipleOf": 1,
      "exclusiveMinimum": 0.99,
      "maximum": 5000,
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func arrayOptions() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONArray()
        .unevaluatedItems { JSONNumber() }
    }

    let expected: [String: JSONValue] = [
      "type": "array",
      "unevaluatedItems": [
        "type": "number"
      ],
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func supplementalArrayOptions() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent<[Double]> {
      JSONArray { JSONNumber() }
        .prefixItems {
          JSONNumber()
          JSONString()
          JSONBoolean()
          JSONInteger()
        }
        .unevaluatedItems { false }
        .contains { JSONNumber() }
        .minContains(1)
        .maxContains(25)
        .minItems(1)
        .maxItems(50)
        .uniqueItems()
    }

    let expected: [String: JSONValue] = [
      "type": "array",
      "items": ["type": "number"],
      "prefixItems": [
        ["type": "number"],
        ["type": "string"],
        ["type": "boolean"],
        ["type": "integer"],
      ],
      "unevaluatedItems": false,
      "contains": [
        "type": "number"
      ],
      "minContains": 1,
      "maxContains": 25,
      "minItems": 1,
      "maxItems": 50,
      "uniqueItems": true,
    ]

    #expect(sample.schemaValue == .object(expected))
  }

}

struct JSONSchemaAnnotationsBuilderTests {
  @Test func allAnnotations() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONNull()
        .title("Title")
        .description("This is the description")
        .comment("Comment")
        .default { "1" }
        .examples {
          "1"
          nil
          false
          [1, 2, 3]
          ["hello": "world"]
        }
        .readOnly(true)
        .writeOnly(false)
        .deprecated(false)
    }

    let expected: [String: JSONValue] = [
      "type": "null",
      "title": "Title",
      "description": "This is the description",
      "default": "1",
      "examples": ["1", nil, false, [1, 2, 3], ["hello": "world"]],
      "readOnly": true,
      "writeOnly": false,
      "deprecated": false,
      "$comment": "Comment",
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func nonValueBuilderAnnotations() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONNull()
        .default("1")
        .examples(["1", nil, false, [1, 2, 3], ["hello": "world"]])
    }

    let expected: [String: JSONValue] = [
      "type": "null",
      "default": "1",
      "examples": ["1", nil, false, [1, 2, 3], ["hello": "world"]],
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func description() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent<(Int?, String?)> {
      JSONObject {
        JSONProperty(key: "productId") {
          JSONInteger().description("The unique identifier for a product")
        }
        JSONProperty(key: "productName") { JSONString().description("Name of the product") }
      }
      .description("A product from Acme's catalog")
    }

    let expected: [String: JSONValue] = [
      "type": "object",
      "properties": [
        "productId": ["type": "integer", "description": "The unique identifier for a product"],
        "productName": ["type": "string", "description": "Name of the product"],
      ],
      "description": "A product from Acme's catalog",
    ]

    #expect(sample.schemaValue == .object(expected))
  }
}

struct JSONAdvancedBuilderTests {
  @Test(arguments: [true, false]) func optional(_ bool: Bool) {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      if bool {
        JSONString()
      }
    }

    #expect(sample.schemaValue == (bool ? .object(["type": "string"]) : .object([:])))
  }

  @Test(arguments: [true, false]) func either(_ bool: Bool) {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      if bool { JSONNumber().maximum(100) } else { JSONNumber() }
    }

    #expect(
      sample.schemaValue
        == .object((bool ? ["type": "number", "maximum": 100] : ["type": "number"]))
    )
  }

  @Test func array() {
    let properties = ["foo", "bar", "baz"]

    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONObject {
        for property in properties {
          JSONProperty(key: property) {
            JSONString()
          }
        }
      }
    }

    let expected: [String: JSONValue] = [
      "type": "object",
      "properties": [
        "foo": ["type": "string"],
        "bar": ["type": "string"],
        "baz": ["type": "string"],
      ],
    ]

    #expect(sample.schemaValue == .object(expected))
  }
}

struct JSONSchemaGroupTests {
  @Test func group() {
    let message = JSONObject {
      JSONProperty(key: "to") { JSONString() }
      JSONProperty(key: "from") { JSONString() }
    }

    let typeExtension = JSONObject {
      JSONProperty(key: "type") {
        JSONAnyValue().constant("message")
      }
    }

    let fullMessage = JSONSchema {
      message
      typeExtension
    }

    let expected: [String: JSONValue] = [
      "type": "object",
      "properties": [
        "to": ["type": "string"],
        "from": ["type": "string"],
        "type": ["const": "message"],
      ],
    ]

    #expect(fullMessage.schemaValue == .object(expected))
  }
}
