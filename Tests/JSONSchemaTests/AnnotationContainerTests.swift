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

    #expect(
      destination.allAnnotations().map(\.instanceLocation) == [root, second.instanceLocation]
    )
    let copied = try #require(destination.annotation(for: Keywords.Properties.self, at: root))
    #expect(copied.value == first.value)
    #expect(copied.schemaLocation == first.schemaLocation)
    #expect(copied.absoluteSchemaLocation == first.absoluteSchemaLocation)

    destination.insert(
      Annotation<Keywords.Properties>(
        keyword: "properties",
        instanceLocation: root,
        schemaLocation: JSONPointer(tokens: ["allOf", "1", "properties"]),
        value: ["a", "b"]
      )
    )
    #expect(
      destination.annotation(for: Keywords.Properties.self, at: root)?.value == ["z", "a", "b"]
    )
    #expect(source.annotation(for: Keywords.Properties.self, at: root)?.value == ["z", "a"])
    #expect(
      destination.annotation(for: Keywords.Properties.self, at: root)?.schemaLocation
        == first.schemaLocation
    )

    source.insert(
      Annotation<Keywords.Properties>(
        keyword: "properties",
        instanceLocation: second.instanceLocation,
        schemaLocation: second.schemaLocation,
        value: ["later"]
      )
    )
    #expect(
      destination.annotation(for: Keywords.Properties.self, at: second.instanceLocation)?.value
        == ["nested"]
    )
    destination.merge(AnnotationContainer())
    #expect(
      destination.allAnnotations().map(\.instanceLocation) == [root, second.instanceLocation, root]
    )
  }

  @Test(arguments: ["allOf", "anyOf"])
  func preservesSourcesAndAggregatesEvaluatedProperties(applicator: String) throws {
    let schema = try Schema(
      instance: """
        {
          "\(applicator)": [
            {"properties": {"x": {"title": "X"}}},
            {"$ref": "#/$defs/y"}
          ],
          "$defs": {"y": {"properties": {"y": {"title": "Y"}}}},
          "unevaluatedProperties": false
        }
        """
    )
    let result = schema.validate(["x": 1, "y": 2])
    #expect(result.isValid)
    let properties = (result.annotations ?? []).filter { $0.keyword == "properties" }
    #expect(properties.map(\.jsonValue) == [["x"], ["y"]])
    #expect(
      properties.map(\.schemaLocation.jsonPointerString) == [
        "/\(applicator)/0/properties", "/$defs/y/properties",
      ]
    )
  }

  @Test func absoluteLocationsRespectResourceBoundaries() throws {
    let schema = try Schema(
      instance: """
        {
          "$id": "https://example.com/root",
          "title": "Root",
          "properties": {
            "local": {"title": "Local"},
            "embedded": {
              "$id": "embedded",
              "title": "Embedded",
              "properties": {"child": {"title": "Child"}}
            },
            "referenced": {"$ref": "embedded"},
            "remote": {"$ref": "https://example.com/remote"},
            "aliased": {"$ref": "https://example.com/retrieval"}
          }
        }
        """,
      remoteSchemas: [
        "https://example.com/remote": [
          "title": "Remote",
          "properties": ["child": ["title": "Remote child"]],
        ],
        "https://example.com/retrieval": [
          "$id": "https://example.com/canonical",
          "title": "Canonical",
        ],
      ]
    )
    let result = schema.validate([
      "local": 1,
      "embedded": ["child": 1],
      "referenced": ["child": 2],
      "remote": ["child": 3],
      "aliased": 4,
    ])
    #expect(result.isValid)
    let titles = (result.annotations ?? []).filter { $0.keyword == "title" }
    #expect(
      titles.map(\.absoluteSchemaLocation?.absoluteString) == [
        "https://example.com/root#/title",
        "https://example.com/root#/properties/local/title",
        "https://example.com/embedded#/title",
        "https://example.com/embedded#/properties/child/title",
        "https://example.com/embedded#/title",
        "https://example.com/embedded#/properties/child/title",
        "https://example.com/remote#/title",
        "https://example.com/remote#/properties/child/title",
        "https://example.com/canonical#/title",
      ]
    )
  }

  @Test func differentRemoteSourcesWithTheSamePointerRemainDistinct() throws {
    let schema = try Schema(
      instance: """
        {"allOf": [
          {"$ref": "https://example.com/one"},
          {"$ref": "https://example.com/two"}
        ]}
        """,
      remoteSchemas: [
        "https://example.com/one": ["default": [1, 2]],
        "https://example.com/two": ["default": [3, 4]],
      ]
    )
    let result = schema.validate(.null)
    let defaults = (result.annotations ?? []).filter { $0.keyword == "default" }
    #expect(defaults.map(\.jsonValue) == [[1, 2], [3, 4]])
    #expect(
      defaults.map(\.absoluteSchemaLocation?.absoluteString) == [
        "https://example.com/one#/default", "https://example.com/two#/default",
      ]
    )
  }

  @Test func repeatedReferenceDoesNotDuplicateAnArrayValuedAnnotation() throws {
    let schema = try Schema(
      instance: """
        {
          "allOf": [{"$ref": "#/$defs/shared"}, {"$ref": "#/$defs/shared"}],
          "$defs": {"shared": {"default": [1e1000, 9.2700]}}
        }
        """
    )
    let defaults = (schema.validate(.null).annotations ?? []).filter { $0.keyword == "default" }
    #expect(defaults.count == 1)
    #expect(try defaults.first?.jsonValue.serialized() == "[1e1000,9.2700]")
  }

  @Test(arguments: ["allOf", "anyOf"])
  func preservesSourcesAndAggregatesEvaluatedItems(applicator: String) throws {
    let schema = try Schema(
      instance: """
        {
          "\(applicator)": [
            {"contains": {"const": 1}},
            {"contains": {"const": 2}}
          ],
          "unevaluatedItems": false
        }
        """
    )
    let result = schema.validate([1, 2])
    #expect(result.isValid)
    let contains = (result.annotations ?? []).filter { $0.keyword == "contains" }
    #expect(contains.map(\.jsonValue) == [[0], [1]])
    #expect(
      contains.map(\.schemaLocation.jsonPointerString) == [
        "/\(applicator)/0/contains", "/\(applicator)/1/contains",
      ]
    )
  }

  @Test func unknownKeywordsRemainSeparateLiteralAnnotations() throws {
    let schema = try Schema(
      instance: """
        {
          "type": "string",
          "x-first": null,
          "x-second": {"$ref": "urn:missing", "default": 1e1000}
        }
        """
    )
    let result = schema.validate("value")
    #expect(result.isValid)
    let annotations = try #require(result.annotations)
    #expect(annotations.map(\.keyword) == ["x-first", "x-second"])
    #expect(annotations.first?.jsonValue == .null)
    #expect(
      try annotations.last?.jsonValue.serialized()
        == #"{"$ref":"urn:missing","default":1e1000}"#
    )
  }

  @Test func mergedAnnotationRetainsAvailableAbsoluteLocation() throws {
    let relative = Annotation<Keywords.Properties>(
      keyword: "properties",
      instanceLocation: .init(),
      schemaLocation: "/properties",
      value: ["x"]
    )
    let absolute = Annotation<Keywords.Properties>(
      keyword: "properties",
      instanceLocation: .init(),
      schemaLocation: "/properties",
      absoluteSchemaLocation: URL(string: "https://example.com/schema#/properties"),
      value: ["y"]
    )
    let merged = try #require(relative.merged(with: absolute))
    #expect(merged.absoluteSchemaLocation == absolute.absoluteSchemaLocation)
    #expect(merged.jsonValue == ["x", "y"])
  }
}
