import JSONSchema
import JSONSchemaBuilder
import Testing

struct JSONIntegerNumberParsingTests {
  @Test(arguments: [0.0, -0.0, 1.0, -2.0, Double(Int.min), Double(Int.max).nextDown])
  func exactIntegralNumbersParseAsInt(value: Double) throws {
    let expected = try #require(Int(exactly: value))
    let input = JSONValue.number(value)
    #expect(JSONInteger().parse(input) == .valid(expected))
    #expect(try JSONInteger().parseAndValidate(input) == expected)
    #expect(input.primitive == .integer)
  }

  @Test(arguments: [
    1.5, -1.5, Double(Int.max),
    Double(Int.min).nextDown,
  ])
  func fractionalAndOutOfRangeNumbersDoNotTrapOrRound(value: Double) {
    #expect(JSONInteger().parse(.number(value)).errors != nil)
    #expect(throws: ParseAndValidateIssue.self) {
      try JSONInteger().parseAndValidate(.number(value))
    }
  }

  @Test func rawDecimalInputAndIntegerStorageBothKeepTheirRepresentation() throws {
    let input = try JSONValue.parse("1.0")
    #expect(try JSONInteger().parseAndValidate(input) == 1)
    #expect(input.integer == 1)
    #expect(input.numberLiteral?.rawValue == "1.0")
    #expect(input.number == 1.0)
    #expect(JSONInteger().parse(.integer(Int.max)) == .valid(Int.max))
    #expect(JSONInteger().parse(.integer(Int.min)) == .valid(Int.min))
  }
}
