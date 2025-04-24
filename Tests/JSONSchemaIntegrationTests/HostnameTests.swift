import InlineSnapshotTesting
import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
struct FieldnameSchema: Equatable {
  let field1: Field

  struct FileExtension: Schemable, Equatable {
    let value: String

    static var schema: some JSONSchemaComponent<FileExtension> {
      JSONSchema(FileExtension.init) {
        JSONString()
          .pattern(#"^[^\\/]+$"#)
      }
    }
  }

  struct Field: Schemable, Equatable {
    let value: [String: [FileExtension]]

    static var schema: some JSONSchemaComponent<Field> {
      JSONSchema(Field.init) {
        JSONObject()
          .patternProperties {
            JSONProperty(key: #"^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"#) {
              JSONArray {
                FileExtension.schema
              }
            }
            .required()
          }
          .map { $1.matches.mapValues(\.value) }
          .unevaluatedProperties { false }
      }
    }
  }
}

struct HostnameTests {
  @Test(.snapshots(record: false)) func schema() {
    let schema = FieldnameSchema.schema.schemaValue

    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "field1" : {
            "patternProperties" : {
              "^(?:[a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}$" : {
                "items" : {
                  "pattern" : "^[^\\\\\/]+$",
                  "type" : "string"
                },
                "type" : "array"
              }
            },
            "type" : "object",
            "unevaluatedProperties" : false
          }
        },
        "required" : [
          "field1"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test func parsing() {
    let json: JSONValue = [
      "field1": [
        "example.com": ["html", "css"],
        "api.test.io": ["json"],
      ]
    ]
    let parsed = FieldnameSchema.schema.parse(json)
    let expected = FieldnameSchema(
      field1: FieldnameSchema.Field(value: [
        "example.com": [
          FieldnameSchema.FileExtension(value: "html"),
          FieldnameSchema.FileExtension(value: "css"),
        ],
        "api.test.io": [
          FieldnameSchema.FileExtension(value: "json")
        ],
      ])
    )
    #expect(parsed.value == expected)
  }

  @Test func validation() {
    let schema = FieldnameSchema.schema.definition()
    let instance: JSONValue = [
      "field1": [
        "example.com": ["html", "css"],
        "api.test.io": ["json"],
      ]
    ]
    let validationResult = schema.validate(instance)
    #expect(validationResult.isValid)

    let annotations = validationResult.annotations ?? []
    // Expect exactly three annotations with the correct keywords
    #expect(
      Set(annotations.map { $0.keyword })
        == Set([
          Keywords.Properties.name,
          Keywords.PatternProperties.name,
          Keywords.UnevaluatedProperties.name,
        ])
    )

    // Check the "properties" annotation value
    if let propAnn = annotations.first(where: { $0.keyword == Keywords.Properties.name }) {
      #expect(Set(propAnn.jsonValue.array ?? []) == Set(["field1"]))
    } else {
      #expect(Bool(false), "Missing properties annotation")
    }

    // Check the "patternProperties" annotation value
    if let patternAnn = annotations.first(where: { $0.keyword == Keywords.PatternProperties.name })
    {
      #expect(Set(patternAnn.jsonValue.array ?? []) == Set(["example.com", "api.test.io"]))
    } else {
      #expect(Bool(false), "Missing patternProperties annotation")
    }

    // Check the "unevaluatedProperties" annotation value
    if let unevalAnn = annotations.first(where: {
      $0.keyword == Keywords.UnevaluatedProperties.name
    }) {
      #expect((unevalAnn.jsonValue.array ?? []).isEmpty)
    } else {
      #expect(Bool(false), "Missing unevaluatedProperties annotation")
    }
  }
}
