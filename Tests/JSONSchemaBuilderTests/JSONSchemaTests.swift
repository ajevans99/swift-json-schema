import JSONSchema
import Testing

@testable import JSONSchemaBuilder

//struct JSONSchemaOptionBuilderTests {
//  @Test func objectOptions() throws {
//    @JSONSchemaBuilder var sample:
//      some JSONSchemaComponent<((String?, String, Bool?, Double), [String: Bool])>
//    {
//      JSONObject {
//        JSONProperty(key: "property0") { JSONString() }
//        JSONProperty(key: "property1") { JSONString() }.required()
//        JSONProperty(key: "property2") { JSONBoolean() }
//        JSONProperty(key: "property3") { JSONNumber() }.required()
//      }
//      .patternProperties { JSONProperty(key: "^property[0-1]$") { JSONString() } }
//      .disableUnevaluatedProperties().propertyNames(.options(pattern: "^property[0-9]$"))
//      .minProperties(1).maxProperties(10).additionalProperties { JSONBoolean() }
//    }
//
//    let options: ObjectSchemaOptions = try #require(sample.definition.options?.asType())
//
//    #expect(
//      options
//        == .options(
//          properties: [
//            "property0": .string(), "property1": .string(), "property2": .boolean(),
//            "property3": .number(),
//          ],
//          patternProperties: [#"^property[0-1]$"#: .string()],
//          additionalProperties: .schema(.boolean()),
//          unevaluatedProperties: .disabled,
//          required: ["property1", "property3"],
//          propertyNames: .options(pattern: #"^property[0-9]$"#),
//          minProperties: 1,
//          maxProperties: 10
//        )
//    )
//  }
//
//  @Test func objectOptionsProperty() throws {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent<(Int?, Double?)> {
//      JSONObject {
//        JSONProperty(key: "key1", value: JSONInteger())
//        JSONProperty(key: "key2") { JSONNumber() }
//      }
//    }
//
//    #expect(
//      sample.definition
//        == Schema.object(
//          .annotations(),
//          .options(properties: ["key1": .integer(), "key2": .number()])
//        )
//    )
//  }
//
//  @Test func supplementalObjectOptions() throws {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
//      JSONObject().disableAdditionalProperties().unevaluatedProperties { JSONInteger() }
//    }
//
//    let options: ObjectSchemaOptions = try #require(sample.definition.options?.asType())
//
//    #expect(
//      options
//        == .options(additionalProperties: .disabled, unevaluatedProperties: .schema(.integer()))
//    )
//  }
//
//  @Test func stringOptions() throws {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent<String> {
//      JSONString().minLength(12).maxLength(36)
//        .pattern("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$").format("uuid")
//    }
//
//    let options: StringSchemaOptions = try #require(sample.definition.options?.asType())
//
//    #expect(
//      options
//        == .options(
//          minLength: 12,
//          maxLength: 36,
//          pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
//          format: "uuid"
//        )
//    )
//  }
//
//  @Test func numberOptions() throws {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent<Double> {
//      JSONNumber().multipleOf(2).minimum(1).exclusiveMaximum(100)
//    }
//
//    let options: NumberSchemaOptions = try #require(sample.definition.options?.asType())
//
//    #expect(sample.definition.type == .number)
//    #expect(options == .options(multipleOf: 2, minimum: .inclusive(1), maximum: .exclusive(100)))
//  }
//
//  @Test func supplementalNumberOptions() throws {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
//      JSONInteger().multipleOf(1).exclusiveMinimum(0.99).maximum(5000)
//    }
//
//    let options: NumberSchemaOptions = try #require(sample.definition.options?.asType())
//
//    #expect(sample.definition.type == .integer)
//    #expect(
//      options == .options(multipleOf: 1, minimum: .exclusive(0.99), maximum: .inclusive(5000))
//    )
//  }
//
//  @Test func arrayOptions() throws {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
//      JSONArray(disableItems: true).unevaluatedItems { JSONNumber() }
//    }
//
//    let options: ArraySchemaOptions = try #require(sample.definition.options?.asType())
//
//    #expect(options == .options(items: .disabled, unevaluatedItems: .schema(.number())))
//  }
//
//  @Test func supplementalArrayOptions() throws {
//
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent<[Double]> {
//      JSONArray { JSONNumber() }
//        .prefixItems {
//          JSONNumber()
//          JSONString()
//          JSONBoolean()
//          JSONInteger()
//        }
//        .disableUnevaluatedItems().contains { JSONNumber() }.minContains(1).maxContains(25)
//        .minItems(1).maxItems(50).uniqueItems()
//    }
//
//    let options: ArraySchemaOptions = try #require(sample.definition.options?.asType())
//
//    #expect(
//      options
//        == .options(
//          items: .schema(.number()),
//          prefixItems: [.number(), .string(), .boolean(), .integer()],
//          unevaluatedItems: .disabled,
//          contains: .number(),
//          minContains: 1,
//          maxContains: 25,
//          minItems: 1,
//          maxItems: 50,
//          uniqueItems: true
//        )
//    )
//  }
//}
//
//struct JSONSchemaAnnotationsBuilderTests {
//  @Test func allAnnotations() throws {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
//      JSONNull().title("Title").description("This is the description").comment("Comment")
//        .default { "1" }
//        .examples {
//          "1"
//          nil
//          false
//          [1, 2, 3]
//          ["hello": "world"]
//        }
//        .readOnly(true).writeOnly(false).deprecated(false)
//    }
//
//    #expect(
//      sample.definition.annotations
//        == .annotations(
//          title: "Title",
//          description: "This is the description",
//          default: "1",
//          examples: ["1", nil, false, [1, 2, 3], ["hello": "world"]],
//          readOnly: true,
//          writeOnly: false,
//          deprecated: false,
//          comment: "Comment"
//        )
//    )
//  }
//
//  @Test func nonValueBuilderAnnotations() throws {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
//      JSONNull().default("1").examples(["1", nil, false, [1, 2, 3], ["hello": "world"]])
//    }
//
//    #expect(
//      sample.definition.annotations
//        == .annotations(default: "1", examples: ["1", nil, false, [1, 2, 3], ["hello": "world"]])
//    )
//  }
//
//  @Test func description() {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent<(Int?, String?)> {
//      JSONObject {
//        JSONProperty(key: "productId") {
//          JSONInteger().description("The unique identifier for a product")
//        }
//        JSONProperty(key: "productName") { JSONString().description("Name of the product") }
//      }
//      .description("A product from Acme's catalog")
//    }
//
//    #expect(
//      sample.definition
//        == .object(
//          .annotations(description: "A product from Acme's catalog"),
//          .options(properties: [
//            "productId": .integer(.annotations(description: "The unique identifier for a product")),
//            "productName": .string(.annotations(description: "Name of the product")),
//          ])
//        )
//    )
//  }
//}
//
//struct JSONAdvancedBuilderTests {
//  @Test(arguments: [true, false]) func optional(_ bool: Bool) {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent { if bool { JSONString() } }
//
//    #expect(sample.definition == (bool ? Schema.string() : .noType()))
//  }
//
//  @Test(arguments: [true, false]) func either(_ bool: Bool) {
//    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
//      if bool { JSONNumber().maximum(100) } else { JSONNumber() }
//    }
//
//    #expect(
//      sample.definition
//        == (bool ? Schema.number(.annotations(), .options(maximum: 100)) : .number())
//    )
//  }
//}
