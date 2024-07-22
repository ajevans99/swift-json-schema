import Foundation
import Testing

@testable import JSONSchema

struct EncodingSchemaTests {
  @Test(arguments: [
    (Schema.string(), JSONType.string), (.integer(), .integer), (.number(), .number),
    (.object(), .object), (.array(), .array), (.boolean(), .boolean), (.null(), .null),
  ]) func type(schema: Schema, type: JSONType) throws {
    #expect(schema.type == type)
    let json = try schema.json()
    #expect(
      json == """
        {
          "type" : "\(type.rawValue)"
        }
        """
    )
  }

  @Test(
    .tags(.annotations),
    arguments: [
      Schema.string(.annotations(title: "Hello")), Schema.integer(.annotations(title: "Hello")),
      Schema.number(.annotations(title: "Hello")), Schema.object(.annotations(title: "Hello")),
      Schema.array(.annotations(title: "Hello")), Schema.boolean(.annotations(title: "Hello")),
      Schema.null(.annotations(title: "Hello")),
    ]
  ) func title(schema: Schema) throws {
    let json = try schema.json()
    let type = try #require(schema.type)
    #expect(
      json == """
        {
          "title" : "Hello",
          "type" : "\(type.rawValue)"
        }
        """
    )
  }

  static let sampleAnnotation = AnnotationOptions(
    title: "Title",
    description: "This is the description",
    default: "1",
    examples: ["1", nil, false, [1, 2, 3], ["hello": "world"]],
    readOnly: true,
    writeOnly: false,
    deprecated: false,
    comment: "Comment"
  )
  @Test(
    .tags(.annotations),
    arguments: [
      Schema.string(sampleAnnotation), Schema.integer(sampleAnnotation),
      Schema.number(sampleAnnotation), Schema.object(sampleAnnotation),
      Schema.array(sampleAnnotation), Schema.boolean(sampleAnnotation),
      Schema.null(sampleAnnotation),
    ]
  ) func allAnnotations(schema: Schema) throws {
    let json = try schema.json()
    let type = try #require(schema.type)
    #expect(
      json == """
        {
          "$comment" : "Comment",
          "default" : "1",
          "deprecated" : false,
          "description" : "This is the description",
          "examples" : [
            "1",
            null,
            false,
            [
              1,
              2,
              3
            ],
            {
              "hello" : "world"
            }
          ],
          "readOnly" : true,
          "title" : "Title",
          "type" : "\(type.rawValue)",
          "writeOnly" : false
        }
        """
    )
  }

  @Test(.tags(.typeOptions)) func stringOptions() throws {
    let schema = Schema.string(
      .annotations(),
      .options(
        minLength: 12,
        maxLength: 36,
        pattern: #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#,
        format: "uuid"
      )
    )
    let json = try schema.json()
    #expect(
      json == """
        {
          "format" : "uuid",
          "maxLength" : 36,
          "minLength" : 12,
          "pattern" : "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
          "type" : "string"
        }
        """
    )
  }

  @Test(.tags(.typeOptions)) func numberOptions() throws {
    let schema1 = Schema.number(
      .annotations(),
      .options(multipleOf: 2, minimum: 1.0, maximum: .exclusive(100))
    )
    let json1 = try schema1.json()
    #expect(
      json1 == """
        {
          "exclusiveMaximum" : 100,
          "minimum" : 1,
          "multipleOf" : 2,
          "type" : "number"
        }
        """
    )

    let schema2 = Schema.number(
      .annotations(),
      .options(multipleOf: 1.0, minimum: .exclusive(0.99), maximum: .inclusive(5000))
    )
    let json2 = try schema2.json()
    #expect(
      json2 == """
        {
          "exclusiveMinimum" : 0.99,
          "maximum" : 5000,
          "multipleOf" : 1,
          "type" : "number"
        }
        """
    )
  }

  @Test(.tags(.typeOptions)) func arrayOptions() throws {
    let schema = Schema.array(
      .annotations(),
      .options(
        items: .schema(.number()),
        prefixItems: [.number(), .string(), .object(), .object()],
        unevaluatedItems: .disabled,
        contains: .number(),
        minContains: 1,
        maxContains: 25,
        minItems: 1,
        maxItems: 50,
        uniqueItems: true
      )
    )
    let json = try schema.json()
    #expect(
      json == """
        {
          "contains" : {
            "type" : "number"
          },
          "items" : {
            "type" : "number"
          },
          "maxContains" : 25,
          "maxItems" : 50,
          "minContains" : 1,
          "minItems" : 1,
          "prefixItems" : [
            {
              "type" : "number"
            },
            {
              "type" : "string"
            },
            {
              "type" : "object"
            },
            {
              "type" : "object"
            }
          ],
          "type" : "array",
          "unevaluatedItems" : false,
          "uniqueItems" : true
        }
        """
    )
  }

  @Test(.tags(.typeOptions)) func objectOptions() throws {
    let schema = Schema.object(
      .annotations(),
      .options(
        properties: [
          "property0": .string(), "property1": .string(), "property2": .boolean(),
          "property3": .number(),
        ],
        patternProperties: [#"^property[0-1]$"#: .string()],
        additionalProperties: .schema(.array()),
        unevaluatedProperties: .disabled,
        required: ["property1", "property3"],
        propertyNames: .options(pattern: #"^property[0-9]$"#),
        minProperties: 1,
        maxProperties: 10
      )
    )
    let json = try schema.json()
    #expect(
      json == """
        {
          "additionalProperties" : {
            "type" : "array"
          },
          "maxProperties" : 10,
          "minProperties" : 1,
          "patternProperties" : {
            "^property[0-1]$" : {
              "type" : "string"
            }
          },
          "properties" : {
            "property0" : {
              "type" : "string"
            },
            "property1" : {
              "type" : "string"
            },
            "property2" : {
              "type" : "boolean"
            },
            "property3" : {
              "type" : "number"
            }
          },
          "propertyNames" : {
            "pattern" : "^property[0-9]$"
          },
          "required" : [
            "property1",
            "property3"
          ],
          "type" : "object",
          "unevaluatedProperties" : false
        }
        """
    )
  }

  @Test(arguments: [
    Schema.string(enumValues: ["Hello", "World"]), Schema.integer(enumValues: ["Hello", "World"]),
    Schema.number(enumValues: ["Hello", "World"]), Schema.object(enumValues: ["Hello", "World"]),
    Schema.array(enumValues: ["Hello", "World"]), Schema.boolean(enumValues: ["Hello", "World"]),
    Schema.null(enumValues: ["Hello", "World"]),
  ]) func enumValue(schema: Schema) throws {
    #expect(schema.enumValues == ["Hello", "World"])
    let json = try schema.json()
    let type = try #require(schema.type)
    #expect(
      json == """
        {
          "enum" : [
            "Hello",
            "World"
          ],
          "type" : "\(type)"
        }
        """
    )
  }

  @Test(arguments: [Schema.noType(enumValues: ["Hello", 1, nil, 4.5])]) func noType(
    schema: Schema
  ) throws {
    #expect(schema.enumValues == ["Hello", 1, nil, 4.5])
    let json = try schema.json()
    #expect(
      json == """
        {
          "enum" : [
            "Hello",
            1,
            null,
            4.5
          ]
        }
        """
    )
  }

  @Test func const() throws {
    let schema = Schema.const(.annotations(), "United States of America")
    let json = try schema.json()
    #expect(
      json == """
        {
          "const" : "United States of America"
        }
        """
    )
  }

  @Test func constWithType() throws {
    let schema = Schema.const(.annotations(), "United States of America", type: .string)
    let json = try schema.json()
    #expect(
      json == """
        {
          "const" : "United States of America",
          "type" : "string"
        }
        """
    )
  }

  @Test func root() throws {
    let schema = RootSchema(
      id: "https://example.com/schemas/myschema",
      schema: "https://json-schema.org/draft/2020-12/schema",
      vocabulary: [
        "https://json-schema.org/draft/2020-12/vocab/core": true,
        "https://json-schema.org/draft/2020-12/vocab/applicator": true,
      ],
      subschema: .object(.annotations(), .options(properties: ["name": .string()]))
    )
    let json = try schema.json()
    #expect(
      json == """
        {
          "$id" : "https:\\/\\/example.com\\/schemas\\/myschema",
          "$schema" : "https:\\/\\/json-schema.org\\/draft\\/2020-12\\/schema",
          "$vocabulary" : {
            "https:\\/\\/json-schema.org\\/draft\\/2020-12\\/vocab\\/applicator" : true,
            "https:\\/\\/json-schema.org\\/draft\\/2020-12\\/vocab\\/core" : true
          },
          "properties" : {
            "name" : {
              "type" : "string"
            }
          },
          "type" : "object"
        }
        """
    )
  }
}

extension RootSchema: @retroactive CustomTestStringConvertible {
  public var testDescription: String { subschema?.testDescription ?? "No subschema" }

  func json() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    return String(decoding: data, as: UTF8.self)
  }
}

extension Schema: @retroactive CustomTestStringConvertible {
  public var testDescription: String { type?.rawValue.capitalized ?? "No explicit type" }

  func json() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    return String(decoding: data, as: UTF8.self)
  }
}
