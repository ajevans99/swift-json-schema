import Foundation
import Testing

@testable import JSONSchema

struct SchemaLifetimeTests {
  @Test(arguments: [
    "true",
    ##"{"type":"string"}"##,
    ##"{"$ref":"https://example.com/text"}"##,
    ##"{"$ref":"#/$defs/text","$defs":{"text":{"type":"string"}}}"##,
    ##"{"type":"object","properties":{"child":{"$ref":"#"}}}"##,
    ##"{"$dynamicAnchor":"node","type":"object","properties":{"child":{"$dynamicRef":"#node"}}}"##,
  ])
  func validationReleasesContextAndConfiguration(document: String) throws {
    weak var context: Context?
    weak var compiledContext: Context?
    weak var validator: LifetimeValidator?
    do {
      let configuration = LifetimeValidator()
      validator = configuration
      let owner = Context(
        dialect: .draft2020_12,
        remoteSchema: ["https://example.com/text": ["type": "string"]],
        formatValidators: [configuration]
      )
      context = owner
      let schema = try Schema(rawSchema: JSONValue.parse(document), context: owner)
      compiledContext = (schema.schema as? ObjectSchema)?.context
      _ = schema.validate(["child": ["child": [:]]])
      _ = schema.validate("hello")
      #expect(context != nil)
      #expect(validator != nil)
    }
    #expect(context == nil)
    // Also detect a detached recursive keyword/resolver graph after its storage
    // has gone away, rather than checking the owning context alone.
    #expect(compiledContext == nil)
    #expect(validator == nil)
  }

  @Test func schemaOutlivesInitializationScope() throws {
    weak var validator: LifetimeValidator?
    var escaped: Schema?
    do {
      let configuration = LifetimeValidator()
      validator = configuration
      escaped = try Schema(
        instance: ##"{"$ref":"#/$defs/text","$defs":{"text":{"type":"string"}}}"##,
        formatValidators: [configuration]
      )
      #expect(escaped?.validate("hello").isValid == true)
    }
    #expect(validator != nil)
    #expect(escaped?.validate("again").isValid == true)
    #expect(escaped?.validate(42).isValid == false)
    escaped = nil
    #expect(validator == nil)
  }

  @Test func shortLivedResolversReuseTheLocalTarget() throws {
    let schema = try Schema(
      instance:
        ##"{"$dynamicAnchor":"node","type":"object","properties":{"child":{"$dynamicRef":"#node"}}}"##
    )
    let targetURL = try #require(URL(string: "#node", relativeTo: schema.documentURL)?.absoluteURL)
    func resolve() throws -> Schema {
      try ReferenceResolver(
        context: schema.context,
        referenceURI: "#node",
        location: .init(),
        baseURI: schema.documentURL
      )
      .resolveSchema(isDynamic: true)
    }
    _ = try resolve()
    let cached = try #require(schema.context.referenceTarget(for: targetURL))
    for _ in 0 ..< 32 {
      #expect(try resolve().validate(["child": [:]]).isValid)
      #expect(schema.context.referenceTarget(for: targetURL)?.context === cached.context)
    }
  }

  @Test func metaSchemaValidationReleasesContext() throws {
    weak var context: Context?
    weak var compiledContext: Context?
    weak var validator: LifetimeValidator?
    do {
      let configuration = LifetimeValidator()
      validator = configuration
      let schema = try Dialect.draft2020_12.loadMetaSchema()
      context = schema.context
      compiledContext = (schema.schema as? ObjectSchema)?.context
      schema.context.formatValidators[configuration.formatName] = configuration
      #expect(schema.validate(["type": "string"]).isValid)
      #expect(!schema.validate(["type": "invalid-type"]).isValid)
    }
    #expect(context == nil)
    // Also detect a detached recursive keyword/resolver graph after its storage
    // has gone away, rather than checking the owning context alone.
    #expect(compiledContext == nil)
    #expect(validator == nil)
  }

  @Test(arguments: [false, true])
  func resolvedSchemaOutlivesResolverAndOriginalSchema(dynamic: Bool) throws {
    weak var validator: LifetimeValidator?
    var escaped: Schema?
    do {
      let configuration = LifetimeValidator()
      validator = configuration
      let context = Context(dialect: .draft2020_12, formatValidators: [configuration])
      let schema = try Schema(
        rawSchema: [
          "$dynamicAnchor": "node", "type": "object",
          "properties": ["child": [dynamic ? "$dynamicRef" : "$ref": dynamic ? "#node" : "#"]],
        ],
        context: context
      )
      let resolver = ReferenceResolver(
        context: context,
        referenceURI: dynamic ? "#node" : "#",
        location: .init(),
        baseURI: schema.documentURL
      )
      escaped = try resolver.resolveSchema(isDynamic: dynamic)
      #expect(escaped != nil)
    }
    #expect(validator != nil)
    #expect(escaped?.validate(["child": ["child": [:]]]).isValid == true)
    #expect(escaped?.validate(["child": 42]).isValid == false)
    escaped = nil
    #expect(validator == nil)
  }
}

private final class LifetimeValidator: FormatValidator, Sendable {
  let formatName = "lifetime"
  func validate(_ value: String) -> Bool { true }
}
