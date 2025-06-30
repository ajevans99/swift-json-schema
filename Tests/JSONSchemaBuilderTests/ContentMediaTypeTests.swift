import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct ContentMediaTypeBuilderTests {
  @Test func encodingAndMediaType() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent<String> {
      JSONString()
        .contentEncoding("base64")
        .contentMediaType("image/png")
    }

    let expected: [String: JSONValue] = [
      "type": "string",
      "contentEncoding": "base64",
      "contentMediaType": "image/png",
    ]

    #expect(sample.schemaValue == .object(expected))
  }
}
