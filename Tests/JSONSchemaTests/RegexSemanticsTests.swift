import Testing

@testable import JSONSchema

struct RegexSemanticsTests {
  @Test(arguments: [
    ("^.$", "e\u{301}", false),
    ("^\u{e9}$", "e\u{301}", false),
    ("^\u{e9}$", "\u{e9}", true),
    (#"^\d$"#, "\u{661}", false),
    (#"^\D$"#, "\u{661}", true),
    (#"^\w$"#, "\u{e9}", false),
    (#"^\W$"#, "\u{e9}", true),
    (#"^\w$"#, "_", true),
    (#"^\s$"#, "\u{a0}", true),
  ])
  func patternsAndPropertyNamesShareScalarAndClassPolicy(
    pattern: String,
    input: String,
    matches: Bool
  ) throws {
    let string = try Schema(
      rawSchema: ["pattern": .string(pattern)],
      context: .init(dialect: .draft2020_12)
    )
    #expect(string.validate(.string(input)).isValid == matches)
    let object = try Schema(
      rawSchema: [
        "patternProperties": .object([pattern: true]),
        "additionalProperties": false,
      ],
      context: .init(dialect: .draft2020_12)
    )
    #expect(object.validate(.object([input: 1])).isValid == matches)
  }
}
