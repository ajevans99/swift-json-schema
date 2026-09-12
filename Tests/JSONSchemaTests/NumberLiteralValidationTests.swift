import Testing

@testable import JSONSchema

struct NumberLiteralValidationTests {
  @Test func parsingAndSerializationPreserveNestedNumericTokens() throws {
    let source =
      #"{"price":9.2700,"values":[9007199254740993,1.2300E+004,-0.00,1e100000,1e-100000]}"#
    let value = try JSONValue.parse(source)

    #expect(try value.serialized() == source)
    #expect(value.object?["price"]?.numberLiteral?.rawValue == "9.2700")
    let values = try #require(value.object?["values"]?.array)
    #expect(
      values.compactMap { $0.numberLiteral?.rawValue }
        == ["9007199254740993", "1.2300E+004", "-0.00", "1e100000", "1e-100000"]
    )
    #expect(try JSONValue.parse(value.serialized()) == value)
  }

  @Test(arguments: [
    ValidationOutputLevel.basic,
    ValidationOutputLevel.detailed,
    ValidationOutputLevel.verbose,
  ])
  func renderedOutputPreservesEnormousNumericAnnotations(level: ValidationOutputLevel) throws {
    let schema = try Schema(instance: #"{"default":1e1000}"#)
    let result = schema.validate(.null)
    #expect(result.isValid)
    let original = try #require(result.annotations?.first { $0.keyword == "default" })
    #expect(original.jsonValue.numberLiteral?.rawValue == "1e1000")

    let output = try result.renderedOutput(level: level)
    #expect(output.object?["valid"] == true)
    let annotations = try #require(output.object?["annotations"]?.array)
    let annotation = try #require(
      annotations.first { $0.object?["keywordLocation"] == "/default" }
    )
    #expect(annotation.object?["annotation"]?.numberLiteral?.rawValue == "1e1000")

    let serialized = try output.serialized()
    #expect(serialized.contains(#""annotation":1e1000"#))
    let roundTrip = try JSONValue.parse(serialized)
    let roundTripAnnotation = try #require(roundTrip.object?["annotations"]?.array?.first)
    #expect(roundTripAnnotation.object?["annotation"]?.numberLiteral?.rawValue == "1e1000")
  }

  @Test(
    arguments: [
      ("9007199254740992", "9007199254740993", "9007199254740994"),
      (
        "0.123456789012345678901234567890123456781",
        "0.123456789012345678901234567890123456782",
        "0.123456789012345678901234567890123456783"
      ),
      (
        "-0.123456789012345678901234567890123456783",
        "-0.123456789012345678901234567890123456782",
        "-0.123456789012345678901234567890123456781"
      ),
      ("9e99999", "1e100000", "1.000000000000000000000000000000000000001e100000"),
      ("9e-100001", "1e-100000", "1.000000000000000000000000000000000000001e-100000"),
      ("-1.000000000000000000000000000000000000001e100000", "-1e100000", "-9e99999"),
      ("-1.000000000000000000000000000000000000001e-100000", "-1e-100000", "-9e-100001"),
    ]
  )
  func rawSchemaBoundsAreExact(below: String, boundary: String, above: String) throws {
    try expectBounds(below: below, boundary: boundary, above: above)
  }

  @Test func adjacentValuesAtIntLimitsRemainDistinct() throws {
    try expectBounds(
      below: String(Int.max - 1),
      boundary: String(Int.max),
      above: "\(Int.max).1"
    )
    try expectBounds(
      below: "\(Int.min).1",
      boundary: String(Int.min),
      above: String(Int.min + 1)
    )
    let maximum = try JSONValue.parse(String(Int.max))
    let previous = try JSONValue.parse(String(Int.max - 1))
    #expect(maximum != previous)
    #expect(Set([maximum, previous]).count == 2)
  }

  private func expectBounds(below: String, boundary: String, above: String) throws {
    for keyword in ["minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum"] {
      let schema = try Schema(instance: #"{"type":"number","\#(keyword)":\#(boundary)}"#)
      let lower = try JSONValue.parse(below)
      let equal = try JSONValue.parse(boundary)
      let upper = try JSONValue.parse(above)
      let isMinimum = keyword == "minimum" || keyword == "exclusiveMinimum"
      let isInclusive = keyword == "minimum" || keyword == "maximum"

      #expect(schema.validate(lower).isValid == !isMinimum, "\(keyword): \(below)")
      #expect(schema.validate(equal).isValid == isInclusive, "\(keyword): \(boundary)")
      #expect(schema.validate(upper).isValid == isMinimum, "\(keyword): \(above)")
      #expect(schema.jsonValue.object?[keyword]?.numberLiteral?.rawValue == boundary)
    }
  }

  @Test(
    arguments: [
      ("1", "1.0"),
      ("1", "10e-1"),
      ("0", "-0.000e+100000"),
      ("123", "1.2300e2"),
      ("9007199254740993", "9007199254740993.0"),
      ("1e100000", "10e99999"),
      ("1e-100000", "0.1e-99999"),
    ]
  )
  func constEnumAndUniquenessUseMathematicalEquality(first: String, second: String) throws {
    let left = try JSONValue.parse(first)
    let right = try JSONValue.parse(second)
    let constant = try Schema(instance: #"{"const":\#(first)}"#)
    let enumeration = try Schema(instance: #"{"enum":[\#(first)]}"#)
    let unique = try Schema(instance: #"{"uniqueItems":true}"#)

    #expect(left == right)
    #expect(Set([left, right]).count == 1)
    #expect(constant.validate(right).isValid)
    #expect(enumeration.validate(right).isValid)
    #expect(!unique.validate(.array([left, right])).isValid)
    #expect(left.numberLiteral?.rawValue == first)
    #expect(right.numberLiteral?.rawValue == second)
  }

  @Test(
    arguments: [
      ("9007199254740992", "9007199254740993"),
      ("9223372036854775807", "9223372036854775808"),
      ("1234567890123456789012345678901234567890", "1234567890123456789012345678901234567891"),
      ("0.1000000000000000000000000000000000000001", "0.1000000000000000000000000000000000000002"),
      ("0", "1e-100000"),
    ]
  )
  func constEnumAndUniquenessDoNotCollapseDistinctNumbers(first: String, second: String) throws {
    let left = try JSONValue.parse(first)
    let right = try JSONValue.parse(second)
    let constant = try Schema(instance: #"{"const":\#(first)}"#)
    let enumeration = try Schema(instance: #"{"enum":[\#(first)]}"#)
    let unique = try Schema(instance: #"{"uniqueItems":true}"#)

    #expect(left != right)
    #expect(Set([left, right]).count == 2)
    #expect(!constant.validate(right).isValid)
    #expect(!enumeration.validate(right).isValid)
    #expect(unique.validate(.array([left, right])).isValid)
  }

  @Test func mathematicalEqualityRecursesThroughContainers() throws {
    let schema = try Schema(instance: #"{"uniqueItems":true}"#)
    let repeated = try JSONValue.parse(#"[{"values":[1,0.30]},{"values":[1.0,3e-1]}]"#)
    let distinct = try JSONValue.parse(#"[{"id":9007199254740992},{"id":9007199254740993}]"#)
    let constant = try Schema(instance: #"{"const":{"values":[1,0.30]}}"#)

    #expect(!schema.validate(repeated).isValid)
    #expect(schema.validate(distinct).isValid)
    #expect(constant.validate(try JSONValue.parse(#"{"values":[1.0,3e-1]}"#)).isValid)
  }

  @Test(
    arguments: [
      ("1.0", true),
      ("1.2300e2", true),
      ("100e-2", true),
      ("-12.300e1", true),
      ("0.0001e4", true),
      ("-0.0e-100000", true),
      ("1e100000", true),
      ("1234567890123456789012345678901234567890", true),
      ("1.2300e1", false),
      ("100e-3", false),
      ("1.000000000000000000000000000000000000001", false),
      ("1e-100000", false),
    ]
  )
  func integerTypeIsMathematicalRatherThanLexical(token: String, isInteger: Bool) throws {
    let instance = try JSONValue.parse(token)
    let integerSchema = try Schema(instance: #"{"type":"integer"}"#)
    let numberSchema = try Schema(instance: #"{"type":"number"}"#)

    #expect(instance.primitive == (isInteger ? .integer : .number))
    #expect(integerSchema.validate(instance).isValid == isInteger)
    #expect(numberSchema.validate(instance).isValid)
    #expect(instance.numberLiteral?.rawValue == token)
  }

  @Test(
    arguments: [
      ("0.3", "0.1", true),
      ("-0.3", "0.1", true),
      ("1", "0.3", false),
      ("0", "0.1", true),
      ("0.3000000000000000000000000000000000000001", "0.1", false),
      ("0.2999999999999999999999999999999999999999", "0.1", false),
      ("1e-100000", "1e-100001", true),
      ("3e-100000", "1e-100000", true),
      ("3.000000000000000000000000000000000000001e-100000", "1e-100000", false),
      ("9007199254740992", "2", true),
      ("9007199254740993", "2", false),
      ("1e100000", "2", true),
      ("1e100000", "3", false),
    ]
  )
  func multipleOfUsesExactArithmetic(token: String, divisor: String, isValid: Bool) throws {
    let schema = try Schema(instance: #"{"multipleOf":\#(divisor)}"#)
    let input = try JSONValue.parse(token)
    let result = schema.validate(input)

    #expect(result.isValid == isValid)
    if !isValid {
      let error = try #require(result.errors?.first)
      #expect(error.keyword == "multipleOf")
      #expect(error.message.contains(token))
      #expect(error.message.contains(divisor))
    }
  }

  @Test(arguments: ["0", "-0.0", "-0.1", "-1e100000", "null", #""0.1""#])
  func invalidDivisorsFailExplicitly(divisor: String) throws {
    let value = try JSONValue.parse(divisor)
    let keyword = Keywords.MultipleOf(value: value)
    let input = try JSONValue.parse("0.3")

    do {
      try keyword.validate(input, at: .init(), using: AnnotationContainer())
      Issue.record("Expected an explicit numeric validation failure")
    } catch {
      guard case .numericValidationFailure(let reason) = error else {
        Issue.record("Expected numericValidationFailure, received \(error)")
        return
      }
      #expect(!reason.isEmpty)
      #expect(reason.contains("multipleOf"))
    }

    let schema = try Schema(instance: #"{"multipleOf":\#(divisor)}"#)
    let result = schema.validate(input)
    #expect(!result.isValid)
    #expect(result.errors?.first?.keyword == "multipleOf")
  }

  @Test func numericValidationIssuesRetainExactOperands() throws {
    let limit = try JSONNumberLiteral("9007199254740992.000")
    let number = try JSONNumberLiteral("9007199254740993.000")
    let keyword = Keywords.Maximum(value: .numberLiteral(limit))

    do {
      try keyword.validate(
        .numberLiteral(number),
        at: .init(),
        using: AnnotationContainer()
      )
      Issue.record("Expected the exact maximum to be exceeded")
    } catch {
      guard case .exceedsMaximum(let actual, let maximum) = error else {
        Issue.record("Expected exceedsMaximum, received \(error)")
        return
      }
      #expect(actual.rawValue == number.rawValue)
      #expect(maximum.rawValue == limit.rawValue)
      #expect(error.description.contains(number.rawValue))
      #expect(error.description.contains(limit.rawValue))
    }
  }

  @Test(arguments: ["Length", "Items", "Contains", "Properties"])
  func enormousCountBoundsDoNotFallBackToIntDefaults(kind: String) throws {
    let input: JSONValue
    switch kind {
    case "Length": input = "abc"
    case "Items", "Contains": input = [1, "unmatched", 2]
    default: input = ["a": 1, "b": 2]
    }
    let contains =
      kind == "Contains" ? #""contains":{"type":"integer"},"# : ""
    for prefix in ["min", "max"] {
      let keyword = prefix + kind
      let schema = try Schema(instance: #"{\#(contains)"\#(keyword)":1e1000}"#)
      let result = schema.validate(input)

      #expect(result.isValid == (prefix == "max"))
      #expect(schema.jsonValue.object?[keyword]?.numberLiteral?.rawValue == "1e1000")
      if prefix == "min" {
        let error = try #require(result.errors?.first)
        #expect(error.keyword == keyword)
        #expect(error.message.contains("1e1000"))
      }
    }
  }

  @Test func enormousContainsBoundsAlsoHandleEveryIndexAnnotations() throws {
    let input: JSONValue = [1, 2, 3]
    let minimum = try Schema(instance: #"{"contains":true,"minContains":1e1000}"#)
    let maximum = try Schema(instance: #"{"contains":true,"maxContains":1e1000}"#)

    #expect(!minimum.validate(input).isValid)
    #expect(maximum.validate(input).isValid)
  }

  @Test(arguments: ["1.5", "-1", "-1e1000", "1e-1000"])
  func invalidCountBoundsReportNumericValidationFailures(token: String) throws {
    let bound = try JSONValue.parse(token)
    let cases: [(String, any AssertionKeyword, JSONValue)] = [
      ("minLength", Keywords.MinLength(value: bound), "abc"),
      ("maxLength", Keywords.MaxLength(value: bound), "abc"),
      ("minItems", Keywords.MinItems(value: bound), [1, 2]),
      ("maxItems", Keywords.MaxItems(value: bound), [1, 2]),
      ("minContains", Keywords.MinContains(value: bound), [1, 2]),
      ("maxContains", Keywords.MaxContains(value: bound), [1, 2]),
      ("minProperties", Keywords.MinProperties(value: bound), ["a": 1]),
      ("maxProperties", Keywords.MaxProperties(value: bound), ["a": 1]),
    ]
    var annotations = AnnotationContainer()
    annotations.insert(
      Annotation<Keywords.Contains>(
        keyword: "contains",
        instanceLocation: .init(),
        schemaLocation: .init(),
        value: .everyIndex
      )
    )

    for (name, keyword, input) in cases {
      do {
        try keyword.validate(input, at: .init(), using: annotations)
        Issue.record("Expected \(name) to reject invalid count bound \(token)")
      } catch {
        guard case .numericValidationFailure(let reason) = error else {
          Issue.record("Expected numericValidationFailure for \(name), received \(error)")
          continue
        }
        #expect(!reason.isEmpty)
        #expect(reason.contains(name))
      }

      let schema = try Schema(instance: #"{"contains":true,"\#(name)":\#(token)}"#)
      let result = schema.validate(input)
      #expect(!result.isValid)
      #expect(result.errors?.contains { $0.keyword == name } == true)
    }
  }
}
