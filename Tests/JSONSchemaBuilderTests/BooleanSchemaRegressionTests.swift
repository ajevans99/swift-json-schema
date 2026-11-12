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
}
