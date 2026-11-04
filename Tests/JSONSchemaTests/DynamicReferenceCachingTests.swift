import Dispatch
import Foundation
import Testing

@testable import JSONSchema

struct DynamicReferenceCachingTests {
  @Test func staticAnchorTargetIsCachedButDynamicOverridesAreNot() throws {
    let alias = "https://mirror.example.com/common"
    let canonical = "https://example.com/common"
    let context = Context(
      dialect: .draft2020_12,
      remoteSchema: [
        alias: [
          "$id": .string(canonical),
          "$dynamicRef": "#node",
          "$defs": ["fallback": ["$dynamicAnchor": "node", "type": "boolean"]],
        ]
      ]
    )
    func overridingSchema(type: String) throws -> Schema {
      let uri = "https://example.com/\(type)"
      return try Schema(
        rawSchema: [
          "$id": .string(uri),
          "$ref": .string(alias),
          "$defs": ["override": ["$dynamicAnchor": "node", "type": .string(type)]],
        ],
        context: context,
        baseURI: #require(URL(string: uri))
      )
    }
    let numbers = try overridingSchema(type: "integer")
    let strings = try overridingSchema(type: "string")
    let fallback = try Schema(rawSchema: ["$ref": .string(alias)], context: context)
    #expect(numbers.validate(42).isValid)
    #expect(strings.validate("hello").isValid)
    #expect(fallback.validate(true).isValid)

    // Both wrappers reuse the cached remote document and its single dynamic reference.
    // Replacing its base document makes any repeated static anchor resolution fail.
    context.cacheSchema(try Schema(rawSchema: false, context: context), at: canonical)
    for _ in 0 ..< 3 {
      #expect(numbers.validate(42).isValid)
      #expect(!numbers.validate("hello").isValid)
      #expect(strings.validate("hello").isValid)
      #expect(!strings.validate(42).isValid)
      #expect(fallback.validate(true).isValid)
      #expect(!fallback.validate(42).isValid)
    }
  }

  @Test(arguments: [false, true])
  func metaSchemaStaticTargetIsReusedWithoutSharingIndependentContexts(isDynamic: Bool) throws {
    let context = try Dialect.draft2020_12.loadMetaSchema().context
    let reference = Dialect.draft2020_12.rawValue + "#meta"
    let baseURI = try #require(URL(string: "https://example.com/reference"))
    let resolver = ReferenceResolver(
      context: context,
      referenceURI: reference,
      location: .init(),
      baseURI: baseURI
    )
    let first = try resolver.resolveSchema(isDynamic: isDynamic)
    #expect(first.context !== context)
    for _ in 0 ..< 3 {
      let next = try resolver.resolveSchema(isDynamic: isDynamic)
      #expect(next.context === first.context)
    }

    let independent = ReferenceResolver(
      context: context,
      referenceURI: reference,
      location: .init(),
      baseURI: baseURI
    )
    let other = try independent.resolveSchema(isDynamic: isDynamic)
    #expect(other.context !== first.context)
  }

  @Test func concurrentColdDynamicReferencesResolveTheirStaticTargetOnce() throws {
    let reference = Dialect.draft2020_12.rawValue + "#meta"
    let resolver = ReferenceResolver(
      context: try Dialect.draft2020_12.loadMetaSchema().context,
      referenceURI: reference,
      location: .init(),
      baseURI: try #require(URL(string: "https://example.com/reference"))
    )
    let contexts = LockIsolated<[Context]>([])
    DispatchQueue.concurrentPerform(iterations: 16) { _ in
      do {
        let schema = try resolver.resolveSchema(isDynamic: true)
        contexts.withLock { $0.append(schema.context) }
      } catch {
        Issue.record(error)
      }
    }
    let resolved = contexts.withLock { $0 }
    #expect(resolved.count == 16)
    let first = try #require(resolved.first)
    #expect(resolved.allSatisfy { $0 === first })
  }
}
