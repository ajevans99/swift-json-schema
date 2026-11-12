import Testing

@testable import JSONSchema

struct AdjacentKeywordTests {
  @Test(arguments: [
    ##"{"$defs":{"p":{"prefixItems":[true]}},"$ref":"#/$defs/p","items":false}"##,
    ##"{"$defs":{"p":{"$dynamicAnchor":"p","prefixItems":[true]}},"$dynamicRef":"#p","items":false}"##,
  ])
  func referencedPrefixItemsDoNotSkipLocalItems(schema: String) throws {
    #expect(try !Schema(instance: schema).validate([1]).isValid)
  }

  @Test(arguments: ["properties", "patternProperties"])
  func referencedPropertiesDoNotExcludeLocalAdditionalProperties(keyword: String) throws {
    let schema = try Schema(
      rawSchema: [
        "$defs": ["p": .object([keyword: ["x": true]])],
        "$ref": "#/$defs/p",
        "additionalProperties": false,
      ],
      context: .init(dialect: .draft2020_12)
    )
    #expect(!schema.validate(["x": 1]).isValid)
  }

  @Test(arguments: ["minContains", "maxContains"])
  func containsBoundsIgnoreNonadjacentContains(keyword: String) throws {
    let schema = try Schema(
      rawSchema: [
        "allOf": [["contains": true]],
        keyword: keyword == "minContains" ? 2 : 0,
      ],
      context: .init(dialect: .draft2020_12)
    )
    #expect(schema.validate([1]).isValid)
  }

  @Test func containsBoundsUseOnlyAdjacentMatches() throws {
    let schema = try Schema(
      instance: """
        {
          "$defs": {"p": {"contains": true}},
          "$ref": "#/$defs/p",
          "contains": {"const": 1},
          "maxContains": 1
        }
        """
    )
    #expect(schema.validate([1, 2]).isValid)
  }

  @Test func remoteAnnotationsWithSameRelativePointerAreNotAdjacent() throws {
    let schema = try Schema(
      instance: """
        {"$ref":"https://example.com/remote","additionalProperties":false}
        """,
      remoteSchemas: ["https://example.com/remote": ["properties": ["x": true]]]
    )
    #expect(!schema.validate(["x": 1]).isValid)
  }

  @Test func unevaluatedKeywordsStillCollectReferencedAnnotations() throws {
    let arrays = try Schema(
      instance:
        ##"{"$defs":{"p":{"prefixItems":[true]}},"$ref":"#/$defs/p","unevaluatedItems":false}"##
    )
    #expect(arrays.validate([1]).isValid)
    #expect(!arrays.validate([1, 2]).isValid)
    let objects = try Schema(
      instance:
        ##"{"$defs":{"p":{"properties":{"x":true}}},"$ref":"#/$defs/p","unevaluatedProperties":false}"##
    )
    #expect(objects.validate(["x": 1]).isValid)
    #expect(!objects.validate(["x": 1, "y": 2]).isValid)
  }
}
