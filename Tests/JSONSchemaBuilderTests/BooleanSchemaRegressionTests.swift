import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct BooleanSchemaRegressionTests {
  @Test(arguments: [false, true])
  func explicitBooleanItemsArePreserved(allowed: Bool) {
    let array = JSONArray { allowed }
    #expect(array.schemaValue["items"] == .boolean(allowed))
    #expect(array.definition().validate([]).isValid)
    #expect(array.definition().validate([1]).isValid == allowed)
  }

  @Test func explicitUnconstrainedItemsAreEvaluated() {
    let boolean = JSONArray { true }.unevaluatedItems { false }
    var unconstrained = JSONAnyValue()
    unconstrained.schemaValue = .object([:])
    let object = JSONArray { unconstrained }.unevaluatedItems { false }
    #expect(boolean.definition().validate([1]).isValid)
    #expect(object.schemaValue["items"] == [:])
    #expect(object.definition().validate([1]).isValid)
    #expect(JSONArray().schemaValue["items"] == nil)
  }

  @Test func annotatingFalseSchemaValuePreservesRejection() throws {
    var value = SchemaValue.boolean(false)
    value["title"] = "Never"
    let schema = try Schema(rawSchema: value.value, context: .init(dialect: .draft2020_12))
    #expect(!schema.validate(.null).isValid)
  }

  @Test(arguments: [false, true])
  func booleanAnnotationsAndNilRemovalAreSafe(allowed: Bool) {
    var value = SchemaValue.boolean(allowed)
    value["title"] = nil
    #expect(value == .boolean(allowed))
    let boolean = JSONBooleanSchema(booleanLiteral: allowed).title("Annotated")
    #expect(boolean.schemaValue["title"] == "Annotated")
    #expect(boolean.definition().validate(.null).isValid == allowed)
    #expect(boolean.schema().validate(.null).isValid == allowed)
    let object = JSONObject().additionalProperties(boolean)
    #expect(object.schemaValue["additionalProperties"]?.object?["title"] == "Annotated")
    #expect(object.definition().validate(["extra": 1]).isValid == allowed)
  }
  @Test(arguments: [false, true])
  func replacingBooleanSchemaUpdatesParsing(allowed: Bool) throws {
    var component = JSONBooleanSchema(booleanLiteral: !allowed)
    component.schemaValue = .boolean(allowed)
    #expect(component.definition().validate(.null).isValid == allowed)
    #expect((component.parse(.null).value != nil) == allowed)
    if allowed { #expect(try component.parseAndValidate(.null)) }
  }

  @Test func replacingBooleanWithObjectUpdatesParsing() throws {
    var component: JSONBooleanSchema = false
    component.schemaValue = ["type": "string"]
    #expect(component.parse("hello").value == true)
    #expect(component.parse(1).value == nil)
    #expect(try component.parseAndValidate("hello"))
  }

  @Test(arguments: ["not", "allOf"])
  func falseSchemaKeywordCannotOverwriteRejection(keyword: String) throws {
    var value = SchemaValue.boolean(false)
    value[keyword] = keyword == "not" ? .boolean(false) : .array([.boolean(true)])
    let schema = try Schema(rawSchema: value.value, context: .init(dialect: .draft2020_12))
    #expect(!schema.validate(.null).isValid)
    #expect(!schema.validate("anything").isValid)
  }

  @Test(arguments: [SchemaDocumentReferences.namedTypes, .reusedTypes])
  func copiedReusableBooleanUsesFinalizedDocument(references: SchemaDocumentReferences) throws {
    let document = try SchemaDocument(references: references) {
      let reusable = JSONReusable(String.self) { JSONString() }
      var boolean: JSONBooleanSchema = false
      boolean.schemaValue = reusable.schemaValue
      return boolean
    }
    #expect(document.definition().validate("hello").isValid)
    #expect(document.parse("hello").value == true)
    #expect(try document.parseAndValidate("hello"))
    #expect(document.parse(42).value == nil)
  }

  @Test func booleanProjectionCannotEscapeRestrictedScope() {
    var boolean: JSONBooleanSchema = false
    boolean.schemaValue = ["type": "string"]
    let context = Context(dialect: .draft2020_12)
    let root = JSONAnyValue().definition(context: context).evaluate("hello")
    let scope = ParsingScope.State(evaluation: root, context: context)
      .descending(to: nil, throughReference: true)
    let result = ParsingScope.$current.withValue(scope) { boolean.parse("hello") }
    #expect(result.value == nil)
  }

  @Test(arguments: [
    SchemaValue.object(["$ref": "#/$defs/Missing"]),
    SchemaValue.object(["$vocabulary": ["https://example.com/custom": true]]),
  ])
  func booleanProjectionRejectsDetachedScopedSchemas(schema: SchemaValue) {
    var boolean: JSONBooleanSchema = false
    boolean.schemaValue = schema
    let context = Context(dialect: .draft2020_12)
    let root = JSONAnyValue().definition(context: context).evaluate("hello")
    let scope = ParsingScope.State(evaluation: root, context: context)
    let result = ParsingScope.$current.withValue(scope) { boolean.parse("hello") }
    #expect(result.value == nil)
  }

}
