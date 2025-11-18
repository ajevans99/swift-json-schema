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
        JSONReference<TestNode>.definition(named: "TestNode")
      }
      .required()
    }
  }

  @Test func referenceEmitsKeywordAndParses() throws {
    let reference = JSONReference<TestNode>.definition(named: "TestNode", location: .definitions)
    #expect(reference.schemaValue == .object(["$ref": "#/definitions/TestNode"]))

    let value: JSONValue = ["name": "leaf"]
    let parsed = reference.parse(value)

    #expect(parsed.value == TestNode(name: "leaf"))
  }

  @Test func remoteReferenceConvenienceBuildsURI() throws {
    let url = "https://example.com/schemas/tree.json"
    let pointer = JSONPointer(tokens: ["$defs", "Tree"])
    let reference = JSONReference<TestNode>.remote(url, pointer: pointer)
    #expect(
      reference.schemaValue
        == .object([
          "$ref": .string("https://example.com/schemas/tree.json#/$defs/Tree")
        ])
    )
  }

  @Test func documentPointerConvenienceEscapesTokens() throws {
    let pointer = JSONPointer(tokens: ["properties", "foo/bar"])
    let reference = JSONReference<TestNode>.documentPointer(pointer)
    #expect(reference.schemaValue == .object(["$ref": "#/properties/foo~1bar"]))
  }

  @Test func referenceValidationUsingSchema() throws {
    var component = Self.referenceHostSchema()
    component.schemaValue["$defs"] = .object([
      "TestNode": TestNode.schema.schemaValue.value
    ])
    let schema = component.definition()

    let valid: JSONValue = ["node": ["name": "leaf"]]
    let invalid: JSONValue = ["node": ["name": 42]]

    #expect(schema.validate(valid).isValid)
    #expect(schema.validate(invalid).isValid == false)
  }

  @Test func dynamicReferenceEmitsKeywordAndParses() throws {
    let reference = JSONDynamicReference<TestNode>()
    #expect(
      reference.schemaValue
        == .object([
          "$dynamicRef": .string("#\(TestNode.defaultAnchor)")
        ])
    )

    let value: JSONValue = ["name": "branch"]
    let parsed = reference.parse(value)

    #expect(parsed.value == TestNode(name: "branch"))
  }

}
