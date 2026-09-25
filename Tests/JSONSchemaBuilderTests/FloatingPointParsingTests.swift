import Foundation
import JSONSchema
import JSONSchemaBuilder
import Testing

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

struct FloatingPointParsingTests {
  @Schemable
  struct Scalars: Equatable {
    let float: Float
    let qualifiedFloat: Swift.Float
    let cgFloat: CGFloat
    let qualifiedCGFloat: Foundation.CGFloat
  }

  @Schemable
  struct Collections: Equatable {
    let float: Float?
    let cgFloat: Swift.Optional<Foundation.CGFloat>
    let floats: [Float]
    let cgFloats: [CGFloat]
    let nestedFloats: Swift.Optional<Swift.Array<Swift.Dictionary<String, Swift.Float>>>
    let nestedCGFloats: [String: [Foundation.CGFloat]]
  }

  @Schemable
  struct Constrained: Equatable {
    @NumberOptions(
      .minimum(try! JSONNumberLiteral("0")),
      .maximum(1),
      .exclusiveMinimum(0),
      .exclusiveMaximum(try! JSONNumberLiteral("1")),
      .multipleOf(try! JSONNumberLiteral("0.25"))
    )
    var float: Float = 0.5

    @NumberOptions(
      .minimum(0),
      .maximum(try! JSONNumberLiteral("1")),
      .exclusiveMinimum(try! JSONNumberLiteral("0")),
      .exclusiveMaximum(1),
      .multipleOf(0.25)
    )
    var cgFloat: Foundation.CGFloat = 0.5

    @NumberOptions(.minimum(0), .maximum(1))
    let optionalFloat: Swift.Float?

    @NumberOptions(.minimum(0), .maximum(1))
    let optionalCGFloat: CGFloat?
  }

  @Schemable
  enum Measurement: Equatable {
    case scalar(Float, cgFloat: Foundation.CGFloat?)
    case collection([Swift.Float], cgFloats: [String: CGFloat])
  }

  #if canImport(CoreGraphics)
    @Schemable
    struct CoreGraphicsModel: Equatable {
      @NumberOptions(.minimum(0), .maximum(10))
      let value: CoreGraphics.CGFloat
      let values: [String: [CoreGraphics.CGFloat]]
    }

    @Test func coreGraphicsQualifiedTypesCompileAndParse() throws {
      let source = #"{"value":1.25,"values":{"x":[2.5]}}"#
      #expect(
        try CoreGraphicsModel.schema.parseAndValidate(instance: source)
          == CoreGraphicsModel(value: 1.25, values: ["x": [2.5]])
      )
      #expect(throws: ParseAndValidateIssue.self) {
        try CoreGraphicsModel.schema.parseAndValidate(instance: #"{"value":-1,"values":{}}"#)
      }
    }
  #endif

  @Test func inferredSchemasProduceRequestedSwiftTypes() throws {
    let source = #"{"float":1.25,"qualifiedFloat":-2.5,"cgFloat":3.75,"qualifiedCGFloat":4}"#
    let expected = Scalars(float: 1.25, qualifiedFloat: -2.5, cgFloat: 3.75, qualifiedCGFloat: 4)
    #expect(try Scalars.schema.parse(instance: source) == .valid(expected))
    #expect(try Scalars.schema.parseAndValidate(instance: source) == expected)
    let properties = try #require(Scalars.schema.schemaValue["properties"]?.object)
    for name in ["float", "qualifiedFloat", "cgFloat", "qualifiedCGFloat"] {
      #expect(properties[name]?.object?["type"] == "number")
    }
    let double: Double = try JSONNumber().parseAndValidate(instance: "1.25")
    #expect(double == 1.25)
  }

  @Test func optionalAndNestedCollectionTypesCompileAndParse() throws {
    let source = """
      {
        "float": 1.25, "cgFloat": 2.5,
        "floats": [1, 2.5], "cgFloats": [3.75, 4],
        "nestedFloats": [{"x": 5.5}], "nestedCGFloats": {"y": [6.25]}
      }
      """
    let expected = Collections(
      float: 1.25,
      cgFloat: 2.5,
      floats: [1, 2.5],
      cgFloats: [3.75, 4],
      nestedFloats: [["x": 5.5]],
      nestedCGFloats: ["y": [6.25]]
    )
    #expect(try Collections.schema.parseAndValidate(instance: source) == expected)
    for source in [
      #"{"floats":[],"cgFloats":[],"nestedCGFloats":{}}"#,
      #"{"float":null,"cgFloat":null,"floats":[],"cgFloats":[],"nestedFloats":null,"nestedCGFloats":{}}"#,
    ] {
      #expect(
        try Collections.schema.parseAndValidate(instance: source)
          == Collections(
            float: nil,
            cgFloat: nil,
            floats: [],
            cgFloats: [],
            nestedFloats: nil,
            nestedCGFloats: [:]
          )
      )
    }
  }

  @Test func enumPayloadsCompileAndParse() throws {
    #expect(
      try Measurement.schema.parseAndValidate(instance: #"{"scalar":{"_0":1.25,"cgFloat":2.5}}"#)
        == .scalar(1.25, cgFloat: 2.5)
    )
    #expect(
      try Measurement.schema.parseAndValidate(instance: #"{"scalar":{"_0":1.25}}"#)
        == .scalar(1.25, cgFloat: nil)
    )
    #expect(throws: ParseAndValidateIssue.self) {
      try Measurement.schema.parseAndValidate(instance: #"{"scalar":{"_0":1.25,"cgFloat":null}}"#)
    }
    #expect(
      try Measurement.schema.parseAndValidate(
        instance: #"{"collection":{"_0":[1.25,2.5],"cgFloats":{"x":3.75}}}"#
      ) == .collection([1.25, 2.5], cgFloats: ["x": 3.75])
    )
  }

  @Test func numberOptionsPreserveConstraintsAndDefaults() throws {
    #expect(
      try Constrained.schema.parseAndValidate(instance: #"{"float":0.25,"cgFloat":0.75}"#)
        == Constrained(float: 0.25, cgFloat: 0.75, optionalFloat: nil, optionalCGFloat: nil)
    )
    let properties = try #require(Constrained.schema.schemaValue["properties"]?.object)
    for name in ["float", "cgFloat"] {
      let schema = try #require(properties[name]?.object)
      #expect(schema["default"] == 0.5)
      #expect(schema["minimum"] == 0)
      #expect(schema["maximum"] == 1)
      #expect(schema["exclusiveMinimum"] == 0)
      #expect(schema["exclusiveMaximum"] == 1)
      #expect(schema["multipleOf"] == 0.25)
      for invalid in ["-0.25", "0", "0.3", "1", "1.25"] {
        let float = name == "float" ? invalid : "0.5"
        let cgFloat = name == "cgFloat" ? invalid : "0.5"
        #expect(throws: ParseAndValidateIssue.self) {
          try Constrained.schema.parseAndValidate(
            instance: #"{"float":\#(float),"cgFloat":\#(cgFloat)}"#
          )
        }
      }
    }
    for name in ["optionalFloat", "optionalCGFloat"] {
      #expect(throws: ParseAndValidateIssue.self) {
        try Constrained.schema.parseAndValidate(
          instance: #"{"float":0.5,"cgFloat":0.5,"\#(name)":-1}"#
        )
      }
    }
  }

  @Test func builderConstraintsRemainAvailableAndValidateOriginalTokens() throws {
    try checkConstraints(JSONFloat())
    try checkConstraints(JSONCGFloat())
  }

  private func checkConstraints<Component: JSONNumberType>(_ component: Component) throws
  where Component.Output: BinaryFloatingPoint {
    let schema =
      component
      .minimum(0)
      .maximum(try JSONNumberLiteral("1"))
      .exclusiveMinimum(try JSONNumberLiteral("0"))
      .exclusiveMaximum(1)
      .multipleOf(try JSONNumberLiteral("0.1"))
    #expect(try schema.parseAndValidate(instance: "0.3") == Component.Output(0.3))
    for token in ["0", "1", "-1", "0.300000000000000000000001"] {
      #expect(throws: ParseAndValidateIssue.self) {
        try schema.parseAndValidate(instance: token)
      }
    }
    let bounded = component.maximum(try JSONNumberLiteral("0.1"))
    #expect(try bounded.parse(instance: "0.100000000000000000001").value != nil)
    #expect(throws: ParseAndValidateIssue.self) {
      try bounded.parseAndValidate(instance: "0.100000000000000000001")
    }
  }

  @Test(arguments: [JSONValue.null, JSONValue.string("1.25"), JSONValue.boolean(true), .array([])])
  func nonNumbersFailWithTypeMismatch(value: JSONValue) {
    #expect(
      JSONFloat().parse(value) == .invalid([.typeMismatch(expected: .number, actual: value)])
    )
    #expect(
      JSONCGFloat().parse(value) == .invalid([.typeMismatch(expected: .number, actual: value)])
    )
  }

  @Test(arguments: [
    "1e39", "-1e39", "1e-46", "-1e-46",
    "1e999999999999999999999999", "1e-999999999999999999999999",
  ])
  func floatRangeFailuresAreExplicit(token: String) throws {
    try checkConversionFailure(JSONFloat(), token: token, target: "Float")
  }

  @Test func cgFloatRangeFailuresAreExplicit() throws {
    let tokens =
      CGFloat.NativeType.self == Float.self
      ? ["1e39", "-1e39", "1e-46", "-1e-46"]
      : ["1e309", "-1e309", "1e-324", "-1e-324"]
    for token in tokens + ["1e999999999999999999999999", "1e-999999999999999999999999"] {
      try checkConversionFailure(JSONCGFloat(), token: token, target: "CGFloat")
    }
  }

  private func checkConversionFailure<Component: JSONNumberType>(
    _ component: Component,
    token: String,
    target: String
  ) throws {
    let input = try JSONValue.parse(token)
    #expect(component.definition().validate(input).isValid)
    let expected = ParseIssue.numericConversionFailed(
      value: input,
      target: target,
      reason: JSONNumberLiteral.ConversionError.outOfRange.description
    )
    #expect(component.parse(input).errors == [expected])
    #expect(try component.parse(instance: token).errors == [expected])
    do {
      _ = try component.parseAndValidate(instance: token)
      Issue.record("Expected a numeric conversion failure for \(target)")
    } catch {
      guard case .parsingFailed(let issues) = error else {
        Issue.record("Expected parsingFailed, received \(error)")
        return
      }
      #expect(issues == [expected])
    }
  }

  @Test func finiteExtremesAndRoundingRemainSupported() throws {
    for value: Float in [.leastNonzeroMagnitude, -.leastNonzeroMagnitude, .greatestFiniteMagnitude]
    {
      #expect(try JSONFloat().parseAndValidate(instance: String(value)) == value)
    }
    for value: CGFloat in [
      .leastNonzeroMagnitude, -.leastNonzeroMagnitude, .greatestFiniteMagnitude,
    ] {
      #expect(try JSONCGFloat().parseAndValidate(instance: String(value.native)) == value)
    }
    let token = "1.0000000596046447753906250000000001"
    let float: Float = try JSONFloat().parseAndValidate(instance: token)
    #expect(float == Float(1).nextUp)
    let cgFloat: CGFloat = try JSONCGFloat().parseAndValidate(instance: token)
    let expected =
      CGFloat.NativeType.self == Float.self
      ? CGFloat(Float(1).nextUp) : CGFloat(try JSONNumberLiteral(token).doubleValue())
    #expect(cgFloat == expected)
  }

  @Test(arguments: ["0", "-0", "0e999999999999999999999999", "-0e-999999999999999999999999"])
  func exactZeroPreservesItsSign(token: String) throws {
    let float = try JSONFloat().parseAndValidate(instance: token)
    let cgFloat = try JSONCGFloat().parseAndValidate(instance: token)
    #expect(float == 0)
    #expect(cgFloat == 0)
    #expect(float.sign == (token.hasPrefix("-") ? .minus : .plus))
    #expect(cgFloat.sign == float.sign)
  }

  @Test func nestedMacroParsingPropagatesConversionFailures() throws {
    for source in [
      #"{"floats":[1e1000],"cgFloats":[],"nestedCGFloats":{}}"#,
      #"{"floats":[],"cgFloats":[1e1000],"nestedCGFloats":{}}"#,
      #"{"floats":[],"cgFloats":[],"nestedFloats":[{"x":1e1000}],"nestedCGFloats":{}}"#,
      #"{"floats":[],"cgFloats":[],"nestedCGFloats":{"x":[1e1000]}}"#,
    ] {
      #expect(try Collections.schema.parse(instance: source).value == nil)
      #expect(throws: ParseAndValidateIssue.self) {
        try Collections.schema.parseAndValidate(instance: source)
      }
    }
    for source in [
      #"{"scalar":{"_0":1e1000,"cgFloat":1}}"#,
      #"{"scalar":{"_0":1,"cgFloat":1e1000}}"#,
    ] {
      #expect(try Measurement.schema.parse(instance: source).value == nil)
      #expect(throws: ParseAndValidateIssue.self) {
        try Measurement.schema.parseAndValidate(instance: source)
      }
    }
  }
}
