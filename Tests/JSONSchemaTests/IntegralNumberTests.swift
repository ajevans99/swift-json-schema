import JSONSchema
import Testing

struct IntegralNumberTests {
  @Test(arguments: [JSONValue.string("integer"), JSONValue.array(["boolean", "integer"])])
  func integerTypeAcceptsIntegralNumbersWithoutChangingStorage(type: JSONValue) throws {
    let schema = try Schema(rawSchema: ["type": type], context: Context(dialect: .draft2020_12))
    let integral = try JSONValue.parse("1.0")
    #expect(integral.primitive == .integer)
    #expect(integral.integer == 1)
    #expect(schema.validate(integral).isValid)
    #expect(schema.validate(.number(-0.0)).isValid)
    #expect(schema.validate(.number(-2.0)).isValid)
    #expect(!schema.validate(.number(1.5)).isValid)
    #expect(integral.numberLiteral?.rawValue == "1.0")
  }

  @Test func schemaIntegerTypeIsNotLimitedToSwiftInt() throws {
    let schema = try Schema(
      rawSchema: ["type": "integer"],
      context: Context(dialect: .draft2020_12)
    )
    #expect(schema.validate(.number(1e30)).isValid)
    #expect(schema.validate(.integer(Int.max)).isValid)
    #expect(schema.validate(.integer(Int.min)).isValid)
  }

  @Test(arguments: ["Length", "Items", "Properties", "Contains"])
  func integralDecimalCountBoundsAreApplied(kind: String) throws {
    let minimumValue: JSONValue = .number(2.0)
    let below: JSONValue
    let equal: JSONValue
    let above: JSONValue
    switch kind {
    case "Length": (below, equal, above) = ("a", "ab", "abc")
    case "Items", "Contains": (below, equal, above) = ([1], [1, 2], [1, 2, 3])
    default: (below, equal, above) = (["a": 1], ["a": 1, "b": 2], ["a": 1, "b": 2, "c": 3])
    }
    for prefix in ["min", "max"] {
      let keyword = prefix + kind
      var raw: JSONValue = .object([keyword: minimumValue])
      if kind == "Contains", case .object(var object) = raw {
        object["contains"] = true
        raw = .object(object)
      }
      let schema = try Schema(rawSchema: raw, context: Context(dialect: .draft2020_12))
      #expect(schema.validate(equal).isValid)
      #expect(schema.validate(below).isValid == (prefix == "max"))
      #expect(schema.validate(above).isValid == (prefix == "min"))
      #expect(try schema.validateAgainstMetaSchema().isValid)
    }
  }

  @Test func decimalZeroMinContainsAllowsNoMatches() throws {
    let raw = try JSONValue.parse(#"{"contains": false, "minContains": 0.0}"#)
    let schema = try Schema(rawSchema: raw, context: Context(dialect: .draft2020_12))
    #expect(schema.validate([]).isValid)
    #expect(schema.validate(["unmatched"]).isValid)
  }
}
