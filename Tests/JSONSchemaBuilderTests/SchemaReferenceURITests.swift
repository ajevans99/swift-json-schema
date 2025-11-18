import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct SchemaReferenceURITests {
  @Test func definitionsInDefsContainer() {
    let uri = SchemaReferenceURI.definition(named: "Tree")
    #expect(uri.rawValue == "#/$defs/Tree")
  }

  @Test func definitionsInLegacyContainer() {
    let uri = SchemaReferenceURI.definition(named: "Tree", location: .definitions)
    #expect(uri.rawValue == "#/definitions/Tree")
  }

  @Test func documentPointerEscapesTokens() {
    let pointer = JSONPointer(tokens: ["properties", "foo/bar", "tilde~value"])
    let uri = SchemaReferenceURI.documentPointer(pointer)
    #expect(uri.rawValue == "#/properties/foo~1bar/tilde~0value")
  }

  @Test func remoteWithoutPointerKeepsURL() {
    let url = "https://example.com/schemas/tree.json"
    let uri = SchemaReferenceURI.remote(url)
    #expect(uri.rawValue == url)
  }

  @Test func remoteWithPointerAppendsFragment() {
    let url = "https://example.com/schemas/tree.json"
    let pointer = JSONPointer(tokens: ["$defs", "Tree"])
    let uri = SchemaReferenceURI.remote(url, pointer: pointer)
    #expect(uri.rawValue == "https://example.com/schemas/tree.json#/$defs/Tree")
  }

  @Test func remoteWithEmptyPointerPointsToRoot() {
    let url = "https://example.com/schemas/tree.json"
    let pointer = JSONPointer(tokens: [])
    let uri = SchemaReferenceURI.remote(url, pointer: pointer)
    #expect(uri.rawValue == "https://example.com/schemas/tree.json#")
  }
}
