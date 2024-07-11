import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct JSONSchemaOptionBuilderTests {
  @Test func objectOptions() throws {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONObject()
        .properties {
          JSONProperty(key: "property0") { JSONString() }
          JSONProperty(key: "property1") { JSONString() }
          JSONProperty(key: "property2") { JSONBoolean() }
          JSONProperty(key: "property3") { JSONNumber() }
        }
        .patternProperties { JSONProperty(key: "^property[0-1]$") { JSONString() } }
        .additionalProperties { JSONArray() }.disableUnevaluatedProperties()
        .required(["property1", "property3"]).propertyNames(.options(pattern: "^property[0-9]$"))
        .minProperties(1).maxProperties(10)
    }

    let options: ObjectSchemaOptions = try #require(sample.schema.options?.asType())

    #expect(
      options
        == .options(
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
  }

  @Test func objectOptionsProperty() throws {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONObject {
        JSONProperty(key: "key1", value: JSONInteger())
        JSONProperty(key: "key2") { JSONNumber() }
      }
    }

    #expect(
      sample.schema
        == Schema.object(
          .annotations(),
          .options(properties: ["key1": .integer(), "key2": .number()])
        )
    )
  }

  @Test func supplementalObjectOptions() throws {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONObject().disableAdditionalProperties().unevaluatedProperties { JSONInteger() }
    }

    let options: ObjectSchemaOptions = try #require(sample.schema.options?.asType())

    #expect(
      options
        == .options(additionalProperties: .disabled, unevaluatedProperties: .schema(.integer()))
    )
  }

  @Test func stringOptions() throws {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONString().minLength(12).maxLength(36)
        .pattern("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$").format("uuid")
    }

    let options: StringSchemaOptions = try #require(sample.schema.options?.asType())

    #expect(
      options
        == .options(
          minLength: 12,
          maxLength: 36,
          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
          format: "uuid"
        )
    )
  }

  @Test func numberOptions() throws {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONNumber().multipleOf(2).minimum(1).exclusiveMaximum(100)
    }

    let options: NumberSchemaOptions = try #require(sample.schema.options?.asType())

    #expect(options == .options(multipleOf: 2, minimum: .inclusive(1), maximum: .exclusive(100)))
  }

  @Test func supplementalNumberOptions() throws {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONNumber().multipleOf(1).exclusiveMinimum(0.99).maximum(5000)
    }

    let options: NumberSchemaOptions = try #require(sample.schema.options?.asType())

    #expect(
      options == .options(multipleOf: 1, minimum: .exclusive(0.99), maximum: .inclusive(5000))
    )
  }

  @Test func arrayOptions() throws {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONArray().disableItems().unevaluatedItems { JSONNumber() }
    }

    let options: ArraySchemaOptions = try #require(sample.schema.options?.asType())

    #expect(options == .options(items: .disabled, unevaluatedItems: .schema(.number())))
  }

  @Test func supplementalArrayOptions() throws {

    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONArray().items { JSONNumber() }
        .prefixItems {
          JSONNumber()
          JSONString()
          JSONObject()
          JSONObject()
        }
        .disableUnevaluatedItems().contains { JSONNumber() }.minContains(1).maxContains(25)
        .minItems(1).maxItems(50).uniqueItems()
    }

    let options: ArraySchemaOptions = try #require(sample.schema.options?.asType())

    #expect(
      options
        == .options(
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
  }
}

struct JSONSchemaAnnotationsBuilderTests {
  @Test func allAnnotations() async throws {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONNull().title("Title").description("This is the description").comment("Comment")
        .default { "1" }
        .examples {
          "1"
          nil
          false
          [1, 2, 3]
          ["hello": "world"]
        }
        .readOnly(true).writeOnly(false).deprecated(false)
    }

    #expect(
      sample.schema.annotations
        == .annotations(
          title: "Title",
          description: "This is the description",
          default: "1",
          examples: ["1", nil, false, [1, 2, 3], ["hello": "world"]],
          readOnly: true,
          writeOnly: false,
          deprecated: false,
          comment: "Comment"
        )
    )
  }

  @Test func description() {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONObject {
        JSONProperty(key: "productId") {
          JSONInteger().description("The unique identifier for a product")
        }
        JSONProperty(key: "productName") { JSONString().description("Name of the product") }
      }
      .description("A product from Acme's catalog")
    }

    #expect(
      sample.schema
        == .object(
          .annotations(description: "A product from Acme's catalog"),
          .options(properties: [
            "productId": .integer(.annotations(description: "The unique identifier for a product")),
            "productName": .string(.annotations(description: "Name of the product")),
          ])
        )
    )
  }
}

struct JSONAdvancedBuilderTests {
  @Test(arguments: [true, false]) func optional(_ bool: Bool) {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable { if bool { JSONString() } }

    #expect(sample.schema == (bool ? Schema.string() : .null()))
  }

  @Test(arguments: [true, false]) func either(_ bool: Bool) {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      if bool { JSONString() } else { JSONInteger() }
    }

    #expect(sample.schema == (bool ? Schema.string() : .integer()))
  }

  @Test func array() throws {
    @JSONSchemaBuilder var sample: JSONSchemaRepresentable {
      JSONArray().prefixItems { for _ in 0 ..< 10 { JSONString() } }
    }

    let options: ArraySchemaOptions = try #require(sample.schema.options?.asType())
    #expect(options.prefixItems?.count == 10)
  }
}
