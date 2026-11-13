import JSONSchemaBuilder
import Testing

struct EnumPayloadRegressionTests {
  @Schemable
  enum Payload: Equatable {
    case explicit(_ lhs: Int, _ rhs: Int)
    case mixed(Int, name: String, _ last: Int)
  }

  @Test func distinctPositionalPayloadsCompileAndParse() throws {
    let explicit = try Payload.schema.parseAndValidate(["explicit": ["_0": 1, "_1": 2]])
    #expect(explicit == .explicit(1, 2))
    let mixed = try Payload.schema.parseAndValidate([
      "mixed": ["_0": 3, "name": "four", "_2": 5]
    ])
    #expect(mixed == .mixed(3, name: "four", 5))
  }
}
