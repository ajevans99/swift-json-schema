import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct SchemaDocumentReferenceMatchingTests {
  private enum Identity {}

  @Test func documentMatchingOnlyIgnoresAnnotationsAndItsOwnRootDefinitions() throws {
    let context = SchemaDocumentContext(rootType: nil, policy: .namedTypes)
    let reference = SchemaDocumentScope.$current
      .withValue(context) {
        JSONReusable(Identity.self) { JSONString() }
      }
      .schemaValue
    #expect(
      !context.matchesReference(
        source: reference.value,
        referenceSchema: reference,
        rootSchema: reference.value
      )
    )
    let root = try context.finish(reference)
    #expect(
      context.matchesReference(
        source: root.value,
        referenceSchema: reference,
        rootSchema: root.value
      )
    )

    var annotated = reference
    annotated["description"] = "At the use site"
    #expect(
      context.matchesReference(
        source: annotated.value,
        referenceSchema: reference,
        rootSchema: root.value
      )
    )

    var constrained = annotated
    constrained["minLength"] = 1
    #expect(
      !context.matchesReference(
        source: constrained.value,
        referenceSchema: reference,
        rootSchema: root.value
      )
    )

    var retargeted = annotated
    retargeted["$ref"] = "#/$defs/other"
    #expect(
      !context.matchesReference(
        source: retargeted.value,
        referenceSchema: reference,
        rootSchema: root.value
      )
    )
    #expect(
      !context.matchesReference(
        source: root.value,
        referenceSchema: retargeted,
        rootSchema: root.value
      )
    )

    #expect(
      !context.matchesReference(
        source: root.value,
        referenceSchema: reference,
        rootSchema: ["type": "array"]
      )
    )

    var changedDefinitions = root
    changedDefinitions["$defs"] = ["other": ["type": "number"]]
    #expect(
      !context.matchesReference(
        source: changedDefinitions.value,
        referenceSchema: reference,
        rootSchema: changedDefinitions.value
      )
    )

    let otherContext = SchemaDocumentContext(rootType: nil, policy: .namedTypes)
    _ = try otherContext.finish(["type": "string"])
    #expect(
      !otherContext.matchesReference(
        source: annotated.value,
        referenceSchema: reference,
        rootSchema: annotated.value
      )
    )
  }
}
