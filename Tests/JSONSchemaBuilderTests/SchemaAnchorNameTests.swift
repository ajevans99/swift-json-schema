import Testing

@testable import JSONSchemaBuilder

struct SchemaAnchorNameTests {
  @Test func preservesAllowedCharacters() {
    let raw = "Module.Type_Name-01.nested"
    #expect(SchemaAnchorName.sanitized(raw) == raw)
  }

  @Test func replacesDisallowedCharacters() {
    let raw = "My Type<Name>"
    #expect(SchemaAnchorName.sanitized(raw) == "My_Type_Name_")
  }

  @Test func replacesColonAndSlash() {
    let raw = "Module.Type_Name-01:/nested"
    #expect(SchemaAnchorName.sanitized(raw) == "Module.Type_Name-01__nested")
  }

  @Test func prefixesInvalidLeadingCharacters() {
    #expect(SchemaAnchorName.sanitized("9Type") == "_9Type")
    #expect(SchemaAnchorName.sanitized("-Type") == "_-Type")
    #expect(SchemaAnchorName.sanitized(".Type") == "_.Type")
  }

  @Test func fallsBackForEmptyInput() {
    #expect(SchemaAnchorName.sanitized("") == "_Anchor")
  }
}
