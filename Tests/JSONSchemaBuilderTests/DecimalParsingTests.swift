import Foundation
import JSONSchema
import JSONSchemaBuilder
import Testing

struct DecimalParsingTests {
  @Schemable
  struct DecimalModel: Codable, Equatable {
    let amount: Decimal
    let highPrecision: Decimal
  }

  @Schemable
  struct DecimalCollections: Codable, Equatable {
    let optionalAmount: Decimal?
    let amounts: [Decimal]
    let qualifiedAmount: Foundation.Decimal
    let qualifiedAmounts: [Foundation.Decimal]
    let optionalQualifiedAmount: Foundation.Decimal?
  }

  @Schemable
  struct ConstrainedDecimalModel: Equatable {
    @NumberOptions(
      .minimum(try! JSONNumberLiteral("9007199254740992.0")),
      .maximum(try! JSONNumberLiteral("9007199254740994.0")),
      .multipleOf(try! JSONNumberLiteral("1.0"))
    )
    let amount: Decimal

    @NumberOptions(
      .exclusiveMinimum(try! JSONNumberLiteral("0.12345678901234567890123456789012345670")),
      .exclusiveMaximum(try! JSONNumberLiteral("0.12345678901234567890123456789012345679")),
      .multipleOf(try! JSONNumberLiteral("1e-38"))
    )
    let qualifiedAmount: Foundation.Decimal
  }

  @Test func discussion146DecimalModelParsesWithoutDoubleRounding() throws {
    let source = #"{"amount":9.27,"highPrecision":12345678901234567890.123456789012345678}"#
    let expected = DecimalModel(
      amount: try decimal("9.27"),
      highPrecision: try decimal("12345678901234567890.123456789012345678")
    )
    let parsed = try DecimalModel.schema.parse(instance: source)
    let validated = try DecimalModel.schema.parseAndValidate(instance: source)

    #expect(parsed == .valid(expected))
    #expect(validated == expected)
    #expect(try JSONDecoder().decode(DecimalModel.self, from: Data(source.utf8)) == expected)
    let properties = try #require(DecimalModel.schema.schemaValue["properties"]?.object)
    #expect(properties["amount"]?.object?["type"] == "number")
    #expect(properties["highPrecision"]?.object?["type"] == "number")
  }

  @Test func macroSupportsOptionalArrayAndQualifiedDecimals() throws {
    let source = """
      {
        "optionalAmount": 9.27,
        "amounts": [9.27, 9007199254740993, 0.12345678901234567890123456789012345678],
        "qualifiedAmount": 12345678901234567890.123456789012345678,
        "qualifiedAmounts": [0.1, 0.2, 0.3],
        "optionalQualifiedAmount": 0.12345678901234567890123456789012345678
      }
      """
    let expected = DecimalCollections(
      optionalAmount: try decimal("9.27"),
      amounts: try [
        decimal("9.27"), decimal("9007199254740993"),
        decimal("0.12345678901234567890123456789012345678"),
      ],
      qualifiedAmount: try decimal("12345678901234567890.123456789012345678"),
      qualifiedAmounts: try [decimal("0.1"), decimal("0.2"), decimal("0.3")],
      optionalQualifiedAmount: try decimal("0.12345678901234567890123456789012345678")
    )

    #expect(try DecimalCollections.schema.parse(instance: source) == .valid(expected))
    #expect(try DecimalCollections.schema.parseAndValidate(instance: source) == expected)
  }

  @Test func macroAllowsMissingOptionalDecimals() throws {
    let source = #"{"amounts":[],"qualifiedAmount":9.27,"qualifiedAmounts":[]}"#
    let parsed = try DecimalCollections.schema.parseAndValidate(instance: source)

    #expect(parsed.optionalAmount == nil)
    #expect(parsed.optionalQualifiedAmount == nil)
    #expect(parsed.amounts.isEmpty)
    #expect(parsed.qualifiedAmounts.isEmpty)
    #expect(parsed.qualifiedAmount == (try decimal("9.27")))
  }

  @Test(
    arguments: [
      "9.27",
      "-9.27",
      "9.2700e0",
      "9007199254740993",
      "12345678901234567890.123456789012345678",
      "0.12345678901234567890123456789012345678",
      "1e-100",
      "1.2300e2",
      "-0.000",
    ]
  )
  func decimalComponentPreservesRepresentableValues(token: String) throws {
    let expected = try decimal(token)
    let input = try JSONValue.parse(token)
    let schema = JSONDecimal()

    #expect(schema.parse(input) == .valid(expected))
    #expect(try schema.parse(instance: token) == .valid(expected))
    #expect(try schema.parseAndValidate(instance: token) == expected)
    #expect(input.numberLiteral?.rawValue == token)
  }

  @Test(arguments: [JSONValue.null, JSONValue.string("9.27"), JSONValue.boolean(true)])
  func decimalComponentRejectsNonNumbers(value: JSONValue) {
    #expect(
      JSONDecimal().parse(value)
        == .invalid([.typeMismatch(expected: .number, actual: value)])
    )
  }

  @Test func nullableDecimalComponentParsesNullAndExactNumbers() throws {
    let schema = JSONDecimal().orNull(style: .type)
    #expect(try schema.parseAndValidate(instance: "null") == nil)
    #expect(try schema.parseAndValidate(instance: "9.27") == (try decimal("9.27")))
    let array = JSONArray { JSONDecimal() }
    #expect(
      try array.parseAndValidate(instance: "[9.27,9007199254740993]")
        == [decimal("9.27"), decimal("9007199254740993")]
    )
  }

  @Test func decimalConstraintsUseLosslessLiteralOverloads() throws {
    let lower = try JSONNumberLiteral("0.12345678901234567890123456789012345670")
    let upper = try JSONNumberLiteral("0.12345678901234567890123456789012345679")
    let step = try JSONNumberLiteral("0.00000000000000000000000000000000000001")
    let schema = JSONDecimal()
      .minimum(lower)
      .maximum(upper)
      .exclusiveMinimum(lower)
      .exclusiveMaximum(upper)
      .multipleOf(step)
    let input = "0.12345678901234567890123456789012345675"

    #expect(schema.schemaValue["minimum"]?.numberLiteral?.rawValue == lower.rawValue)
    #expect(schema.schemaValue["maximum"]?.numberLiteral?.rawValue == upper.rawValue)
    #expect(schema.schemaValue["exclusiveMinimum"]?.numberLiteral?.rawValue == lower.rawValue)
    #expect(schema.schemaValue["exclusiveMaximum"]?.numberLiteral?.rawValue == upper.rawValue)
    #expect(schema.schemaValue["multipleOf"]?.numberLiteral?.rawValue == step.rawValue)
    #expect(try schema.parseAndValidate(instance: input) == (try decimal(input)))

    for rejected in [
      "0.12345678901234567890123456789012345669",
      lower.rawValue,
      upper.rawValue,
      "0.12345678901234567890123456789012345680",
    ] {
      #expect(throws: ParseAndValidateIssue.self) {
        try schema.parseAndValidate(instance: rejected)
      }
    }
  }

  @Test func decimalMultipleOfNeverUsesFloatingPointTolerance() throws {
    let schema = JSONDecimal().multipleOf(try JSONNumberLiteral("0.1"))
    #expect(try schema.parseAndValidate(instance: "0.3") == (try decimal("0.3")))
    for rejected in [
      "0.30000000000000000000000000000000000001",
      "0.29999999999999999999999999999999999999",
    ] {
      #expect(throws: ParseAndValidateIssue.self) {
        try schema.parseAndValidate(instance: rejected)
      }
    }
    let thirds = JSONDecimal().multipleOf(try JSONNumberLiteral("0.3"))
    #expect(throws: ParseAndValidateIssue.self) {
      try thirds.parseAndValidate(instance: "1")
    }
  }

  @Test func doubleConvenienceConstraintsRemainAvailableForDecimals() throws {
    let schema = JSONDecimal()
      .minimum(0.0)
      .maximum(1.0)
      .exclusiveMinimum(0.0)
      .exclusiveMaximum(1.0)
      .multipleOf(0.1)
    #expect(try schema.parseAndValidate(instance: "0.3") == (try decimal("0.3")))
  }

  @Test func numberOptionsMacroPreservesLiteralConstraints() throws {
    let fraction = "0.12345678901234567890123456789012345675"
    let source = #"{"amount":9007199254740993,"qualifiedAmount":\#(fraction)}"#
    let expected = ConstrainedDecimalModel(
      amount: try decimal("9007199254740993"),
      qualifiedAmount: try decimal(fraction)
    )
    #expect(try ConstrainedDecimalModel.schema.parseAndValidate(instance: source) == expected)

    let properties = try #require(ConstrainedDecimalModel.schema.schemaValue["properties"]?.object)
    let amount = try #require(properties["amount"]?.object)
    #expect(amount["minimum"]?.numberLiteral?.rawValue == "9007199254740992.0")
    #expect(amount["maximum"]?.numberLiteral?.rawValue == "9007199254740994.0")
    #expect(amount["multipleOf"]?.numberLiteral?.rawValue == "1.0")
    let qualified = try #require(properties["qualifiedAmount"]?.object)
    #expect(
      qualified["exclusiveMinimum"]?.numberLiteral?.rawValue
        == "0.12345678901234567890123456789012345670"
    )
    #expect(
      qualified["exclusiveMaximum"]?.numberLiteral?.rawValue
        == "0.12345678901234567890123456789012345679"
    )
    #expect(qualified["multipleOf"]?.numberLiteral?.rawValue == "1e-38")

    for rejected in [
      #"{"amount":9007199254740991,"qualifiedAmount":\#(fraction)}"#,
      #"{"amount":9007199254740995,"qualifiedAmount":\#(fraction)}"#,
      #"{"amount":9007199254740993.1,"qualifiedAmount":\#(fraction)}"#,
      #"{"amount":9007199254740993,"qualifiedAmount":0.12345678901234567890123456789012345670}"#,
      #"{"amount":9007199254740993,"qualifiedAmount":0.12345678901234567890123456789012345679}"#,
    ] {
      #expect(throws: ParseAndValidateIssue.self) {
        try ConstrainedDecimalModel.schema.parseAndValidate(instance: rejected)
      }
    }
  }

  @Test(arguments: ["1e309", "-1e309", "1e-1000", "-1e-1000", "1e-324"])
  func doubleOverflowAndNonzeroUnderflowFailExplicitly(token: String) throws {
    try expectNumericConversionFailure(JSONNumber(), token: token, target: "Double")
  }

  @Test(arguments: ["5e-324", "-5e-324", "1.7976931348623157e308", "-1.7976931348623157e308"])
  func representableDoubleExtremesRemainFiniteAndNonzero(token: String) throws {
    let value = try JSONNumber().parseAndValidate(instance: token)
    #expect(value.isFinite)
    #expect(value != 0)
    #expect(value == Double(token))
  }

  @Test(arguments: ["0", "-0.000e-100000", "0e100000"])
  func exactZeroIsNotReportedAsDoubleUnderflow(token: String) throws {
    #expect(try JSONNumber().parseAndValidate(instance: token) == 0)
  }

  @Test(
    arguments: [
      "1.234567890123456789012345678901234567890123456789",
      "123456789012345678901234567890123456789012345678901",
      "1e1000",
      "-1e1000",
      "1e-1000",
      "-1e-1000",
    ]
  )
  func decimalPrecisionAndRangeFailuresAreExplicit(token: String) throws {
    try expectNumericConversionFailure(JSONDecimal(), token: token, target: "Decimal")
  }

  @Test func integerParsingAcceptsExactIntLimitsWithDecimalAndExponentSpellings() throws {
    for value in [Int.min, Int.max] {
      for token in ["\(value)", "\(value).0", "\(value)0e-1"] {
        #expect(try JSONInteger().parseAndValidate(instance: token) == value)
        #expect(try JSONValue.parse(token).integer == value)
      }
    }
    #expect(try JSONInteger().parseAndValidate(instance: "1.2300e2") == 123)
  }

  @Test func integerPrecisionAndRangeFailuresAreExplicit() throws {
    for token in ["\(Int.max)0", "\(Int.min)0", "1.000000000000000000000000000000001"] {
      let input = try JSONValue.parse(token)
      let errors = try #require(JSONInteger().parse(input).errors)
      try expectConversionIssue(errors, input: input, target: "Int")
      #expect(input.integer == nil)
      #expect(throws: ParseAndValidateIssue.self) {
        try JSONInteger().parseAndValidate(instance: token)
      }
    }
  }

  @Test func collectionAndMacroParsingPropagateDecimalConversionFailures() throws {
    let token = "0.123456789012345678901234567890123456789012345678901"
    let input = try JSONValue.parse(token)
    let array = JSONArray { JSONDecimal() }
    let arrayErrors = try #require(try array.parse(instance: "[9.27,\(token)]").errors)
    try expectConversionIssue(arrayErrors, input: input, target: "Decimal")
    let source = #"{"amount":9.27,"highPrecision":\#(token)}"#
    let modelErrors = try #require(try DecimalModel.schema.parse(instance: source).errors)
    try expectConversionIssue(modelErrors, input: input, target: "Decimal")
    #expect(throws: ParseAndValidateIssue.self) {
      try DecimalModel.schema.parseAndValidate(instance: source)
    }
  }

  @Test func explicitDecoderCompatibilityOverloadsStillParseOrdinaryNumbers() throws {
    #expect(try JSONNumber().parse(instance: "9.25", decoder: JSONDecoder()) == .valid(9.25))
    #expect(
      try JSONNumber().parseAndValidate(instance: "9.25", decoder: JSONDecoder()) == 9.25
    )
  }

  private func decimal(_ token: String) throws -> Decimal {
    try #require(Decimal(string: token, locale: Locale(identifier: "en_US_POSIX")))
  }

  private func expectNumericConversionFailure<Component: JSONSchemaComponent>(
    _ component: Component,
    token: String,
    target: String
  ) throws {
    let input = try JSONValue.parse(token)
    #expect(component.definition().validate(input).isValid)
    let direct = component.parse(input)
    #expect(direct.value == nil)
    try expectConversionIssue(try #require(direct.errors), input: input, target: target)
    let parsed = try component.parse(instance: token)
    #expect(parsed.value == nil)
    try expectConversionIssue(try #require(parsed.errors), input: input, target: target)

    do {
      _ = try component.parseAndValidate(instance: token)
      Issue.record("Expected a numeric conversion failure for \(target)")
    } catch {
      guard case .parsingFailed(let issues) = error else {
        Issue.record("Expected parsingFailed, received \(error)")
        return
      }
      try expectConversionIssue(issues, input: input, target: target)
    }
  }

  private func expectConversionIssue(
    _ issues: [ParseIssue],
    input: JSONValue,
    target: String
  ) throws {
    #expect(issues.count == 1)
    let issue = try #require(issues.first)
    guard case .numericConversionFailed(let actual, let actualTarget, let reason) = issue else {
      Issue.record("Expected numericConversionFailed, received \(issue)")
      return
    }
    #expect(actual.numberLiteral?.rawValue == input.numberLiteral?.rawValue)
    #expect(actualTarget == target)
    #expect(!reason.isEmpty)
  }
}
