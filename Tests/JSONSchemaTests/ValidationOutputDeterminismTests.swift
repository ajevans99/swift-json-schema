import Foundation
import JSONSchema
import OrderedCollections
import Testing

/// Phase 2 of #149 — validation output (annotations) must be deterministic.
@Suite("Validation output determinism (#149 Phase 2)")
struct ValidationOutputDeterminismTests {

  // MARK: - Properties annotation order matches instance order

  @Test
  func propertiesAnnotationFollowsInstanceKeyOrder() throws {
    let schemaValue: JSONValue = [
      "properties": [
        "alpha": ["type": "integer"],
        "beta": ["type": "integer"],
        "gamma": ["type": "integer"],
      ]
    ]
    let schema = try Schema(rawSchema: schemaValue, context: Context(dialect: .draft2020_12))

    // Instance keys in z → m → a order.
    let instance: JSONValue = [
      "gamma": 3,
      "beta": 2,
      "alpha": 1,
    ]

    let result = schema.validate(instance)
    let propertiesAnnotation = try #require(
      result.annotations?.first { $0.keyword == "properties" }
    )
    let value = try #require(propertiesAnnotation.jsonValue.array)
    let names = value.compactMap { $0.string }

    // Annotation lists matched property names in *instance* declaration order.
    #expect(names == ["gamma", "beta", "alpha"])
  }

  // MARK: - All annotations are emitted in traversal order

  @Test
  func allAnnotationsAreEmittedInDeterministicOrder() throws {
    let schemaValue: JSONValue = [
      "properties": [
        "x": ["type": "string"],
        "y": ["type": "string"],
      ]
    ]
    let schema = try Schema(rawSchema: schemaValue, context: Context(dialect: .draft2020_12))
    let instance: JSONValue = ["y": "value", "x": "value"]

    // Validate twice in the same process — collected annotation order should
    // match exactly. (Hash-randomized Dictionary storage would have given a
    // different ordering on each insert before Phase 2.)
    let first = schema.validate(instance).annotations ?? []
    let second = schema.validate(instance).annotations ?? []

    let firstSig = first.map { "\($0.keyword)@\($0.instanceLocation.jsonPointerString)" }
    let secondSig = second.map { "\($0.keyword)@\($0.instanceLocation.jsonPointerString)" }
    #expect(firstSig == secondSig)
  }

  // MARK: - DependentSchemas iterates in declared order

  @Test
  func dependentSchemasIterateInDeclaredOrder() throws {
    // Each dependent schema annotates a *different* sub-property's title.
    // Putting the title at distinct instance locations avoids the merge
    // collapse that happens when multiple annotations share a keyword +
    // instance location. The order the title annotations appear in the
    // result reflects the iteration order over schemaMap.
    let schemaValue: JSONValue = [
      "dependentSchemas": [
        "z_trigger": ["properties": ["unique_z": ["title": "z"]]],
        "m_trigger": ["properties": ["unique_m": ["title": "m"]]],
        "a_trigger": ["properties": ["unique_a": ["title": "a"]]],
      ]
    ]
    let schema = try Schema(rawSchema: schemaValue, context: Context(dialect: .draft2020_12))
    let instance: JSONValue = [
      "z_trigger": true,
      "m_trigger": true,
      "a_trigger": true,
      "unique_z": 0,
      "unique_m": 0,
      "unique_a": 0,
    ]

    let result = schema.validate(instance)
    let titles = (result.annotations ?? [])
      .compactMap { ann -> String? in
        guard ann.keyword == "title" else { return nil }
        if case .string(let s) = ann.jsonValue { return s }
        return nil
      }

    // Triggers walked in declared (z, m, a) order — *not* alphabetical (a, m, z).
    #expect(titles == ["z", "m", "a"])
  }

  // MARK: - UnevaluatedProperties

  @Test
  func unevaluatedPropertiesAnnotationFollowsInstanceOrder() throws {
    let schemaValue: JSONValue = [
      "properties": ["known": ["type": "string"]],
      "unevaluatedProperties": ["type": "string"],
    ]
    let schema = try Schema(rawSchema: schemaValue, context: Context(dialect: .draft2020_12))
    // Instance in z → m → a order with `known` somewhere in the middle.
    let instance: JSONValue = [
      "z_extra": "z",
      "known": "yes",
      "m_extra": "m",
      "a_extra": "a",
    ]

    let result = schema.validate(instance)
    let unevaluated = try #require(
      result.annotations?.first { $0.keyword == "unevaluatedProperties" }
    )
    guard case .array(let elements) = unevaluated.jsonValue else {
      Issue.record("Expected unevaluatedProperties annotation to be a JSON array")
      return
    }
    let names = elements.compactMap { $0.string }

    // Order matches the instance, minus `known` (consumed by `properties`).
    #expect(names == ["z_extra", "m_extra", "a_extra"])
  }
}
