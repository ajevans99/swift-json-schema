import Foundation
import Testing

@testable import JSONSchema

struct AnnotationContainerTests {
  @Test func emptyMergePreservesOrderMetadataAndValueSemantics() throws {
    let root = JSONPointer()
    let first = Annotation<Keywords.Properties>(
      keyword: "properties",
      instanceLocation: root,
      schemaLocation: JSONPointer(tokens: ["allOf", "0", "properties"]),
      absoluteSchemaLocation: URL(string: "https://example.com/schema#/allOf/0/properties"),
      value: ["z", "a"]
    )
    let second = Annotation<Keywords.Properties>(
      keyword: "properties",
      instanceLocation: JSONPointer(tokens: ["child"]),
      schemaLocation: JSONPointer(tokens: ["properties", "child", "properties"]),
      value: ["nested"]
    )
    var source = AnnotationContainer()
    source.insert(first)
    source.insert(second)
    var destination = AnnotationContainer()
    destination.merge(source)

    #expect(destination.allAnnotations().map(\.instanceLocation) == [root, second.instanceLocation])
    let copied = try #require(destination.annotation(for: Keywords.Properties.self, at: root))
    #expect(copied.value == first.value)
    #expect(copied.schemaLocation == first.schemaLocation)
    #expect(copied.absoluteSchemaLocation == first.absoluteSchemaLocation)

    destination.insert(
      Annotation<Keywords.Properties>(
        keyword: "properties", instanceLocation: root,
        schemaLocation: JSONPointer(tokens: ["allOf", "1", "properties"]),
        value: ["a", "b"]
      )
    )
    #expect(destination.annotation(for: Keywords.Properties.self, at: root)?.value == ["z", "a", "b"])
    #expect(source.annotation(for: Keywords.Properties.self, at: root)?.value == ["z", "a"])
    #expect(
      destination.annotation(for: Keywords.Properties.self, at: root)?.schemaLocation
        == first.schemaLocation
    )

    source.insert(
      Annotation<Keywords.Properties>(
        keyword: "properties", instanceLocation: second.instanceLocation,
        schemaLocation: second.schemaLocation, value: ["later"]
      )
    )
    #expect(
      destination.annotation(for: Keywords.Properties.self, at: second.instanceLocation)?.value
        == ["nested"]
    )
    destination.merge(AnnotationContainer())
    #expect(destination.allAnnotations().map(\.instanceLocation) == [root, second.instanceLocation])
  }
}
