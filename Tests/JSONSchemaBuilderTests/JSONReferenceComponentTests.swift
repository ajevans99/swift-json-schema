import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct JSONReferenceComponentTests {
  private struct TestNode: Schemable, Equatable {
    let name: String

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    static var schema: some JSONSchemaComponent<TestNode> {
      JSONSchema(TestNode.init) {
        JSONObject {
          JSONProperty(key: "name") {
            JSONString()
          }
          .required()
        }
      }
    }
  }

  @JSONSchemaBuilder
  private static func referenceHostSchema() -> some JSONSchemaComponent {
    JSONObject {
      JSONProperty(key: "node") {
        JSONReference<TestNode>(uri: "#/$defs/TestNode")
      }
      .required()
    }
  }

  @Test func referenceEmitsKeywordAndParses() throws {
    let reference = JSONReference<TestNode>(uri: "#/definitions/TestNode")
    #expect(reference.schemaValue == .object(["$ref": "#/definitions/TestNode"]))

    let value: JSONValue = ["name": "leaf"]
    let parsed = reference.parse(value)

    #expect(parsed.value == TestNode(name: "leaf"))
  }

  @Test func referenceValidationUsingSchema() throws {
    var component = Self.referenceHostSchema()
    component.schemaValue["$defs"] = .object([
      "TestNode": TestNode.schema.schemaValue.value,
    ])
    let schema = component.definition()

    let valid: JSONValue = ["node": ["name": "leaf"]]
    let invalid: JSONValue = ["node": ["name": 42]]

    #expect(schema.validate(valid).isValid)
    #expect(schema.validate(invalid).isValid == false)
  }

  @Test func dynamicReferenceEmitsKeywordAndParses() throws {
    let reference = JSONDynamicReference<TestNode>(anchor: "Tree")
    #expect(reference.schemaValue == .object(["$dynamicRef": "#Tree"]))

    let value: JSONValue = ["name": "branch"]
    let parsed = reference.parse(value)

    #expect(parsed.value == TestNode(name: "branch"))
  }

}
