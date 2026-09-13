import Foundation
import Testing

@testable import JSONSchema

struct NumericEvaluationFailureTests {
  @Test(arguments: [
    #"{"multipleOf":3}"#,
    #"{"not":{"multipleOf":3}}"#,
    #"{"not":{"not":{"multipleOf":3}}}"#,
    #"{"anyOf":[true,{"multipleOf":3}]}"#,
    #"{"oneOf":[true,{"multipleOf":3}]}"#,
    #"{"not":{"allOf":[{"multipleOf":3}]}}"#,
    #"{"if":{"multipleOf":3},"then":false,"else":true}"#,
    ##"{"$defs":{"number":{"multipleOf":3}},"not":{"$ref":"#/$defs/number"}}"##,
    ##"{"$defs":{"number":{"multipleOf":3}},"not":{"$dynamicRef":"#/$defs/number"}}"##,
  ])
  func exhaustionCannotBecomeSuccessfulValidation(source: String) throws {
    let schema = try Schema(instance: source)
    let input = try JSONValue.parse(String(repeating: "3", count: 4_097))
    let result = schema.validate(input)
    #expect(!result.isValid)
    #expect(!result.isEvaluationComplete)
    #expect(result.errors?.isEmpty == false)
    let failures = try #require(result.evaluationErrors)
    #expect(leaves(failures).allSatisfy { $0.keyword == "multipleOf" })
    #expect(leaves(failures).allSatisfy { $0.instanceLocation == .init() })
    #expect(
      leaves(failures)
        .allSatisfy {
          $0.message
            == "Cannot evaluate 'multipleOf': \(JSONNumberLiteral.ConversionError.arithmeticResourceLimit)"
        }
    )
    #expect(!schema.evaluate(input).result.isEvaluationComplete)
  }

  @Test(arguments: [
    (#"{"contains":{"multipleOf":3}}"#, "[%s,3]"),
    (#"{"not":{"items":{"multipleOf":3}}}"#, "[%s]"),
    (#"{"not":{"prefixItems":[{"multipleOf":3}]}}"#, "[%s]"),
    (#"{"not":{"properties":{"n":{"multipleOf":3}}}}"#, #"{"n":%s}"#),
    (#"{"not":{"patternProperties":{".*":{"multipleOf":3}}}}"#, #"{"n":%s}"#),
    (#"{"not":{"additionalProperties":{"multipleOf":3}}}"#, #"{"n":%s}"#),
    (#"{"not":{"unevaluatedProperties":{"multipleOf":3}}}"#, #"{"n":%s}"#),
    (#"{"not":{"unevaluatedItems":{"multipleOf":3}}}"#, "[%s]"),
    (#"{"not":{"dependentSchemas":{"n":{"properties":{"n":{"multipleOf":3}}}}}}"#, #"{"n":%s}"#),
  ])
  func exhaustionPropagatesFromNestedInstances(source: String, template: String) throws {
    let schema = try Schema(instance: source)
    let input = try JSONValue.parse(
      template.replacingOccurrences(of: "%s", with: String(repeating: "3", count: 4_097))
    )
    let result = schema.validate(input)
    #expect(!result.isValid)
    #expect(!result.isEvaluationComplete)
    let failures = try #require(result.evaluationErrors)
    #expect(
      leaves(failures)
        .allSatisfy {
          $0.instanceLocation == (template.hasPrefix("[") ? "/0" : "/n")
        }
    )
  }

  @Test func ordinaryMismatchesAndLaterEvaluationsRemainComplete() throws {
    let schema = try Schema(instance: #"{"not":{"multipleOf":3}}"#)
    let huge = try JSONValue.parse(String(repeating: "3", count: 4_097))
    #expect(!schema.validate(huge).isEvaluationComplete)
    let accepted = schema.validate(1)
    #expect(accepted.isValid)
    #expect(accepted.isEvaluationComplete)
    #expect(accepted.evaluationErrors == nil)
    let rejected = schema.validate(3)
    #expect(!rejected.isValid)
    #expect(rejected.isEvaluationComplete)
    #expect(rejected.jsonValue.object?["evaluationErrors"] == nil)
  }

  @Test func unvisitedConditionalBranchesDoNotCauseExhaustion() throws {
    let schema = try Schema(instance: #"{"if":false,"then":{"multipleOf":3},"else":true}"#)
    let huge = try JSONValue.parse(String(repeating: "3", count: 4_097))
    let result = schema.validate(huge)
    #expect(result.isValid)
    #expect(result.isEvaluationComplete)
  }

  @Test func evaluationDiagnosticsSerializeAndReferencesKeepLocations() throws {
    let schema = try Schema(
      instance: ##"{"$defs":{"number":{"multipleOf":3}},"not":{"$ref":"#/$defs/number"}}"##
    )
    let result = schema.validate(
      try JSONValue.parse(String(repeating: "3", count: 4_097))
    )
    let failures = try #require(result.evaluationErrors)
    #expect(leaves(failures).map(\.keywordLocation) == ["/not/$ref/multipleOf"])
    #expect(
      leaves(failures).first?.absoluteKeywordLocation?.fragment == "/$defs/number/multipleOf"
    )
    #expect(result.jsonValue.object?["evaluationErrors"]?.array?.isEmpty == false)
    let encoded = try JSONValue.parse(JSONEncoder().encode(result))
    #expect(encoded == result.jsonValue)
    #expect(try result.renderedOutput(level: .flag) == false)
    for level in [ValidationOutputLevel.basic, .detailed, .verbose] {
      #expect(try result.renderedOutput(level: level).object?["valid"] == false)
    }
  }

  @Test(arguments: [#"{"not":{"multipleOf":0}}"#, #"{"not":{"minItems":0.5}}"#])
  func invalidNumericConstraintsCannotBeNegated(source: String) throws {
    let schema = try Schema(instance: source)
    let result = schema.validate(source.contains("minItems") ? .array([]) : .integer(3))
    #expect(!result.isValid)
    #expect(!result.isEvaluationComplete)
  }

  private func leaves(_ errors: [ValidationError]) -> [ValidationError] {
    errors.flatMap { error in
      if let children = error.errors, !children.isEmpty {
        return leaves(children)
      }
      return [error]
    }
  }
}
