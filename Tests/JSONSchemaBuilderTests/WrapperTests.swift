import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct WrapperTests {
  @Test func optionalComponent() {
    let opt = JSONComponents.OptionalComponent<JSONString>(wrapped: nil)
    let result = opt.parse(.string("hi"))
    switch result {
    case .valid(let value):
      #expect(value == nil)
    default:
      Issue.record("expected valid result")
    }
  }

  @Test func erasedComponent() {
    let any = JSONString().eraseToAnySchemaComponent()
    #expect(any.schemaValue == JSONString().schemaValue)
  }

  @Test func passthrough() {
    let passthrough = JSONComponents.PassthroughComponent(wrapped: JSONString())
    let result = passthrough.parse(.string("hi"))
    #expect(result.value == .string("hi"))
  }

  @Test func runtimeComponent() throws {
    let raw: JSONValue = ["type": "string"]
    let runtime = try RuntimeComponent(rawSchema: raw)
    #expect(runtime.parse(.string("abc")).value == .string("abc"))
  }

  @Test func anyValueInit() {
    let any = JSONAnyValue(JSONString())
    #expect(any.schemaValue.object?[Keywords.TypeKeyword.name] == .string("string"))
  }
}
